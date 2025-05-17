using Gumbo, Cascadia

include("Files.jl")
using .Files

include("Readers.jl")
using .Readers

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

results = Any[]

r = Readers.Reader()
put!(r, "https://storage.canalblog.com/74/29/538763/118476300.pdf")
put!(r, "test.pdf")

put!(r, "https://rheto62.canalblog.com/archives/2019/03/17/37184901.html")
s = take!(r)

put!(r, url)

while !isempty(r)
    s = take!(r)
    
    parsed = parsehtml(s)

    m = eachmatch(Selector("meta[property='og:type']"), parsed.root)
    if !isempty(m)
        pagetype = attrs(first(m))["content"]
        println("Content type: $pagetype")

        if pagetype == "blog"

            next = eachmatch(Selector("a.ob-page-next"), parsed.root)
            println("Size of next: $(length(next))")
            !isempty(next) && put!(r, url * attrs(first(next))["href"])
            
            articles = eachmatch(Selector("div.article"), parsed.root)
            
            for a in articles
                title = get_text(a, "h2.article_title")
                date = get_text(a, "div.date-header")
                
                content_div = get_section(a, "div.ob-section-html")
                content = get_text(a, "div.ob-section-html")
                
                files = isnothing(content_div) ? File[] : get_files(content_div, "a")
                
                push!(results, (title=title, date=date, content=content, files=files))
            end
        
        elseif pagetype == "article"
            m = eachmatch(sel"div.single-content_content p", parsed.root)

        else
            println("Unexpected page type: $pagetype")
        end
    else
        println("not og:type tag")
    end
end

put!(r, "https://rheto62.canalblog.com/archives/2019/03/17/37184901.html")
s = take!(r)
parsed = parsehtml(s)

fn_s = eachmatch(sel"nav.breadcrumb ul li", parsed.root) |> last |> nodeText
date_s = eachmatch(sel"div.date-header", parsed.root) |> first |> nodeText

m = eachmatch(sel"div.single-content_content p", parsed.root) .|> nodeText



close(r)