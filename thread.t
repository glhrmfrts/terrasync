local C = terralib.includecstring [[
#include <stdio.h>
#include <string.h>
#include <pthread.h>
]]

local E = require 'terrasync.error'

local M = {}


-- ThreadImpl: basic wrapper around a pthread

local struct ThreadImpl {
    pt : C.pthread_t
}

terra ThreadImpl:init(fp: {&opaque} -> {&opaque}, arg: &opaque): E.Error
    return E.Error{ C.pthread_create(&self.pt, nil, fp, arg) }
end

terra ThreadImpl:join()
    C.pthread_join(self.pt, nil)
end

terra M.makethreadimpl(fp: {&opaque} -> {&opaque}, arg: &opaque): {ThreadImpl, E.Error}
    var th : ThreadImpl
    var err = th:init(fp, arg)
    return th, err
end


-- Thread: templated version which supports custom functions and arguments

function M.Thread(Func, Arg)
    local struct Thread {
        handle: ThreadImpl
        func: Func
        arg: Arg
    }
    local terra execfunc(arg: &opaque): &opaque
        var t: &Thread = [&Thread](arg)
        t.func(t.arg)
        return nil
    end
    terra Thread:init(f: Func, arg: Arg): E.Error
        self.func = f
        self.arg = arg
        var handle, err = M.makethreadimpl(execfunc, [&opaque](self))
        self.handle = handle
        return err
    end
    terra Thread:join()
        self.handle:join()
    end
    return Thread
end

M.makethread = macro(function(...)
    local args = {...}
    local argtypes = {}
    for i,arg in ipairs(args) do
        table.insert(argtypes, arg:gettype())
    end

    local ThreadType = M.Thread(unpack(argtypes))
    return quote
        var t: ThreadType
        var err = t:init([ args[1] ], [ args[2] ])
    in
        t, err
    end
end)

return M