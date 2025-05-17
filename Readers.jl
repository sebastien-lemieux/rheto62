module Readers

using HTTP

export Reader, put!, take!, isempty

mutable struct Reader
    in::Channel{String}
    out::Channel{String}
    read_task::Task
    write_task::Task
end

function Reader(debug=false)
    println("new_reader v11")
    in = Channel{String}(10)
    out = Channel{String}(10)

    cmd() = open(`node scrape.js`, "r+")
    p = debug ? withenv(cmd, "DEBUG" => "pw:api") : cmd()
    readuntil(p, "<<<READY>>>")

    read_task = Threads.@spawn begin
        while true
            u = take!(in)
            if u == "shutdown"
                println("read: shutdown")
                write(p, "shutdown\n")
                flush(p)
                break
            elseif u == "url"
                url = take!(in)
                println("html")
                write(p, url * "\n")
                flush(p)
            elseif u == "file"
                url = take!(in)
                println("file | {$url}")
                ext = last(splitext(url))
                fn = take!(in)
                resp = try
                    HTTP.get(url, status_exception=false)
                catch e
                    println("File get error: $e")
                    continue
                end
                resp.status != 200 && continue # lost file...
                fpath = joinpath("outputs", fn)
                @show fpath
                open(fpath * ext, "w") do io
                    write(io, resp.body)
                end
            else
                println("Not sure what to do with [$u]")
            end
        end

    end

    write_task = Threads.@spawn begin
        while true
            s = readuntil(p, "<<<END>>>")
            if strip(s) == "shutdown"
                println("write: shutdown")
                put!(out, "shutdown")
                break
            end
            put!(out, s)
        end
    end

    bind(in, read_task)
    bind(out, write_task)

    return Reader(in, out, read_task, write_task)
end    

Base.put!(r::Reader, fn::String) = put!(r.in, fn)
Base.put!(r::Reader, typ::String, url::String) = (put!(r.in, typ); put!(r.in, url))
Base.take!(r::Reader) = take!(r.out)
Base.isempty(r::Reader) = isempty(r.out)
Base.close(r::Reader) = put!(r, "shutdown")

end