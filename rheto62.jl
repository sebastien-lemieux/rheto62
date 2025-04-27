using Gumbo, Cascadia

include("Files.jl")
using .Files

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

results = []
for page = 1:3
    println("$url/page/$page")
    output = read(`/u/lemieuxs/.nvm/versions/node/v23.11.0/bin/node scrape.js $url/page/$page`, String)

    parsed = parsehtml(output)

    articles = eachmatch(Selector("div.article"), parsed.root)

    for a in articles
        title = get_text(a, "h2.article_title")
        date = get_text(a, "div.date-header")

        content_div = get_section(a, "div.ob-section-html")
        content = get_text(a, "div.ob-section-html")

        files = isnothing(content_div) ? File[] : get_files(content_div, "a")

        push!(results, (title=title, date=date, content=content, files=files))

    end
end

