# using Revise
using Gumbo, Cascadia
using DataFrames

include("Readers.jl")
using .Readers

# Revise.track(Readers, "Readers.jl")
# Revise.track(Readers, "Files.jl")

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

df = DataFrame(titre = String[], date = String[], contenu=String[])

r = Readers.Reader()

put!(r, "url", url)

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
                put!(r, "url", link)
            end
        
        elseif pagetype == "article"

            title = get_text(parsed.root, "h2.title")
            date = get_text(parsed.root, "div.date-header")
            
            content_div = get_section(parsed.root, "div.ob-section-html")
            content = get_text(parsed.root, "div.ob-section-html")
            
            matches = eachmatch(Selector("a"), content_div)
            for a in matches
                href = String(attrs(a)["href"])
                !startswith(href, "http") && continue
                println("FILE: [$href]")
                put!(r, "file", String(attrs(a)["href"]))
                put!(r, String(date * "-" * text(a)))
            end
            push!(df, (titre=title, date=date, contenu=content))
        else
            println("Unexpected page type: $pagetype")
        end
    else
        println("not og:type tag")
    end
end

close(r);
