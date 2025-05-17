module Readers

using HTTP

export Reader, put!, take!, fetch, isempty

mutable struct Reader
    in::Channel{String}
    out::Channel{String}
    task::Task
    inflight::Int
end

function Reader(cmd = `DEBUG=pw:api node scrape.js`)
    in = Channel{String}(10)
    out = Channel{String}(10)

    p = withenv("DEBUG" => "pw:api") do
        open(`node scrape.js`, "r+")
    end
    readuntil(p, "<<<READY>>>")

    task = Threads.@spawn begin
        while true
            u = take!(in)
            u == "shutdown" && break

            if endswith(u, ".pdf")
                fn = take!(in)
                r = HTTP.get(u)
                fpath = joinpath("outputs", fn)
                open(fpath, "w") do io
                    write(io, r.body)
                end
                # put!(out, (type = :pdf, data = r.body))
            else
                write(p, u * "\n")
                flush(p)
                s = readuntil(p, "<<<END>>>")
                put!(out, s)
            end
        end

    end
    bind(in, task)
    bind(out, task)

    return Reader(in, out, task, 0)
end    

Base.put!(r::Reader, url::String) = (r.inflight += 1; put!(r.in, url))
Base.take!(r::Reader) = (r.inflight -= 1; take!(r.out))
Base.fetch(r::Reader) = fetch(r.out)
Base.isempty(r::Reader) = (r.inflight == 0)
Base.close(r::Reader) = put!(r, "shutdown")

end