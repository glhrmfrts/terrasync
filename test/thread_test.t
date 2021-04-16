terralib.includepath = terralib.includepath .. ";C:\\code\\terra\\terrasync\\include\\pthreads4w"
package.terrapath = package.terrapath .. ";C:\\code\\terra\\?.t"

local C = terralib.includecstring [[
#include <stdio.h>
#include <string.h>
#include <windows.h>
]]

local M = require 'terrasync.mutex'
local T = require 'terrasync.thread'

local struct State {
    mutex: M.Mutex
    okay: bool
}

local terra printstuff(arg: &State)
    C.Sleep(5000)
    C.printf("Hello world from thread!\n")

    [ M.withlock(`arg.mutex, quote arg.okay=true end) ]
end

terra main(argc: int, argv: &rawstring)
    var mutex, merr = M.makemutex()
    if merr:iserror() then
        C.printf("Error creating mutex: %s\n", merr:getstring())
        return
    end
    defer mutex:destroy()

    var state = State{ mutex, false }

    var t, terr = T.makethread(printstuff, &state)
    if terr:iserror() then
        C.printf("Error creating thread: %s\n", terr:getstring())
        return
    end
    defer t:join()

    C.printf("%d\n", state.okay)

    var i: int = 0
    while true do
        [ M.withlock(`state.mutex, quote
            if state.okay then break end
        end) ]

        C.printf("Hello world from main: %d!\n", i)
        C.Sleep(1000)
        i = i + 1
    end

    C.printf("%d\n", state.okay)
end

terralib.saveobj("build/thread_test.exe", { main = main }, { "/link", "C:\\code\\terra\\terrasync\\libs\\x64\\pthreads4w.lib" })