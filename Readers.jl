module Readers

using HTTP

export Reader, put!, take!, clear!, isempty

mutable struct Reader
    in::Channel{String}
    out::Channel{String}
    read_task::Task
    write_task::Task
end

function Reader(debug=false)
    println("new_reader v12")
    in = Channel{String}(1000)
    out = Channel{String}(1000)

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
                @show fn * ext
                open(fn * ext, "w") do io
                    write(io, resp.body)
                end
            else
                println("Not sure what to do with [$u]")
            end
        end
        println("Reader.read_task: done")
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
        println("Reader.write_task: done")
    end

    bind(in, read_task)
    bind(out, write_task)

    return Reader(in, out, read_task, write_task)
end    

clear!(r::Reader) = while isready(r.out) take!(r.out) end
Base.put!(r::Reader, fn::String) = put!(r.in, fn)
Base.put!(r::Reader, typ::String, url::String) = (put!(r.in, typ); put!(r.in, url))
Base.take!(r::Reader) = take!(r.out)
Base.isempty(r::Reader) = isempty(r.out)
Base.close(r::Reader) = begin clear!(r); put!(r, "shutdown") end

end