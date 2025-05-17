using Revise
using Gumbo, Cascadia
using DataFrames

include("Readers.jl")
using .Readers

Revise.track(Readers, "Readers.jl")
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

url = "https://rheto62.canalblog.com/"

results = Any[]

r = Readers.Reader()

# put!(r, "shutdown")
# put!(r, "https://storage.canalblog.com/74/29/538763/118476300.pdf")
# put!(r, "test.pdf")

# put!(r, "https://rheto62.canalblog.com/archives/2019/03/17/37184901.html")
# s = take!(r)

put!(r, "url", url)

c = 0
while true
    c += 1
    c ≥ 15 && break
    s = take!(r)
    println("HTML: [$(length(s)) $(s[1:30])]")
    
    parsed = parsehtml(s)

    m = eachmatch(Selector("meta[property='og:type']"), parsed.root)
    if !isempty(m)
        pagetype = attrs(first(m))["content"]
        println("Content type: $pagetype")

        if pagetype == "blog"
            next = eachmatch(Selector("a.ob-page-next"), parsed.root)
            # println("Size of next: $(length(next))")
            !isempty(next) && put!(r, "url", url * attrs(first(next))["href"])
            
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
                println("FILE: [$(String(attrs(a)["href"]))]")
                put!(r, "file", String(attrs(a)["href"]))
                put!(r, String(text(a)))
            end
            push!(results, (title=title, date=date, content=content))
        else
            println("Unexpected page type: $pagetype")
        end
    else
        println("not og:type tag")
    end
end
put!(r, "shutdown")
close(r)

r = Reader(true)
for _=1:15
    put!(r, "https://rheto62.canalblog.com/archives/2019/03/17/37184901.html")
end
s = take!(r)
parsed = parsehtml(s)
m = eachmatch(Selector("meta[property='og:type']"), parsed.root)
pagetype = attrs(first(m))["content"]
println("Content type: $pagetype")


fn_s = eachmatch(sel"nav.breadcrumb ul li", parsed.root) |> last |> nodeText
date_s = eachmatch(sel"div.date-header", parsed.root) |> first |> nodeText

m = eachmatch(sel"div.single-content_content p", parsed.root) .|> nodeText



close(r)
