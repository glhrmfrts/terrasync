terralib.includepath = terralib.includepath .. ";C:\\code\\terra\\terrasync\\include\\pthreads4w"
package.terrapath = package.terrapath .. ";C:\\code\\terra\\?.t"

local C = terralib.includecstring [[
#include <stdio.h>
#include <string.h>
#include <windows.h>
]]

local A = require 'terrasync.atomic'
local T = require 'terrasync.thread'

local struct State {
    counter:    A.AtomicInt
    okay:       A.AtomicBool
}

local terra increment(arg: &State)
    arg.counter:fetchadd(1)
    arg.okay:fetchexchange(true)
end

terra main(argc: int, argv: &rawstring)
    var state = State{ counter = A.AtomicInt{ 0 }, okay = A.makeatomic(false) }

    for i=0,10 do
        var t, terr = T.makethread(increment, &state)
        if terr:iserror() then
            C.printf("Error creating thread: %s\n", terr:getstring())
            return
        end
        defer t:join()

        state.counter:fetchadd(1)
    end

    C.printf("20 = %d\n", state.counter:fetch())
end

terralib.saveobj("build/atomic_test.exe", { main = main }, { "/link", "C:\\code\\terra\\terrasync\\libs\\x64\\pthreads4w.lib" })