module Files

using Gumbo, Cascadia

export File

struct File
    name::String
    url::String
end

File(a::HTMLElement{:a}) = File(String(text(a)), String(attrs(a)["href"]))

end