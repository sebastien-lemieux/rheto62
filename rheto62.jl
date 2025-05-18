using Revise
using Gumbo, Cascadia
using DataFrames, CSV
using UUIDs

include("Readers.jl")
using .Readers

Revise.track(Readers, "Readers.jl")

# function put_albums!(r::Reader, url)
#     put!(r, "url", url)

#     s = take!(r)
#     parsed = parsehtml(s)

#     m = eachmatch(Selector("a.ob-widget_albums_link"), parsed.root)
#     for link in m
#         put!(r, "url", attrs(link)["href"])
#     end
# end


isalbum(root) = !isempty(eachmatch(Selector("div.album"), root))

function get_text(root, selector_str)
    matches = eachmatch(Selector(selector_str), root)
    return isempty(matches) ? "" : text(first(matches))
end

function get_section(root, selector_str)
    matches = eachmatch(Selector(selector_str), root)
    return isempty(matches) ? nothing : first(matches)
end

function get_files(root, selector_str)
    matches = eachmatch(Selector(selector_str), root)
    res = File[]
    for a in matches
        push!(res, File(a))
    end
    return res
end

url = "https://rheto62.canalblog.com"

df = DataFrame(titre = String[], date = String[], contenu=String[], id=String[])

r = Readers.Reader()
album_done = false

task = @async while true
    s = take!(r)
    length(s) == 0 && continue
    if s == "shutdown"
        println("task: shutdown")
        break
    end
    println("HTML: [$(length(s))]")
    
    parsed = parsehtml(s)
    
    m = eachmatch(Selector("meta[property='og:type']"), parsed.root)
    if !isempty(m)
        pagetype = attrs(first(m))["content"]
        println("Content type: $pagetype")
        
        if pagetype == "blog"
            @show isempty(eachmatch(Selector("div.album"), parsed.root))
            @show isalbum(parsed.root)
            if isalbum(parsed.root)
                album_title = eachmatch(Selector("h2.title"), parsed.root)[1] |> text
                path = mkpath("archive/$album_title")
                println("Album: $album_title -> $path")

                m = eachmatch(Selector("img.ob-slideshow-img"), parsed.root)
                for img in m
                    fn = attrs(img)["alt"]
                    url = attrs(img)["src"]
                    @show fn, url
                    put!(r, "file", url)
                    put!(r, "$path/$fn")
                end
            else
                println("Blog page: ...")
                next = eachmatch(Selector("a.ob-page-next"), parsed.root)
                println("Size of next: $(length(next))")
                !isempty(next) && begin
                    println("***** got next $(url * attrs(first(next))["href"])")
                    put!(r, "url", url * attrs(first(next))["href"])
                end

                articles = eachmatch(Selector("div.article"), parsed.root)

                for a in articles
                    matches = eachmatch(Selector("a.article_link"), a)
                    isempty(matches) && continue
                    link = String(attrs(first(matches))["href"])
                    println("ARTICLE LINK: [$link]")
                    put!(r, "url", link)
                end

                global album_done
                if !album_done
                    m = eachmatch(Selector("a.ob-widget_albums_link"), parsed.root)
                    for link in m
                        put!(r, "url", attrs(link)["href"])
                    end
                    album_done = true
                end
            end

        elseif pagetype == "article"
            id = string(uuid4())
            title = get_text(parsed.root, "h2.title")
            date = get_text(parsed.root, "div.date-header")
            println("Article: [$title] [$date]")
            
            content_div = get_section(parsed.root, "div.ob-section-html")
            content = get_text(parsed.root, "div.ob-section-html")
            
            matches = eachmatch(Selector("a"), content_div)
            
            for a in matches
                path = mkpath("archive/$title-$date-$id")
                href = String(attrs(a)["href"])
                !startswith(href, "http") && continue
                @show href
                fn = text(a)
                if fn == ""
                    matches = eachmatch(Selector("img"), a)
                    if isempty(matches)
                        fn = first(splitext(basename(s)))
                    else
                        fn = attrs(first(matches))["alt"]
                    # @show fn, href
                    # put!(r, "file", href)
                    # put!(r, "$path/$fn")
                    end
                end
                println("FILE: [$href] [$fn]")
                put!(r, "file", String(attrs(a)["href"]))
                put!(r, "$path/$fn") # String(date * "-" * text(a)))
            end
            push!(df, (titre=title, date=date, contenu=content, id=id))
        else
            println("Unexpected page type: $pagetype")

        end
    else
        println("not og:type tag")
    end
    println("DEALT")
end

# put_albums!(r, url)
put!(r, "url", url)

close(r)

open("archive/article.csv", "w") do io
    write(io, codeunits("\ufeff"))       # Write UTF-8 BOM
    CSV.write(io, df; append=true)   # French/English Excel-compatible
end
