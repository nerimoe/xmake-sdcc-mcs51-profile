-- 运行以生成配置文件
-- xmake f -p mcs51 --toolchain=sdcc -a mcs51 --sdk="/bin"


add_rules("mode.debug", "mode.release")

local xram_size = 1024
local iram_size = 256
local code_size = 16384
local xram_loc = 276
local freq = 24000000
add_defines("F_CPU ="..freq)

add_includedirs(
    "include",
)

add_cflags("-mmcs51")
add_cflags("--peep-asm")
add_cflags("--peep-return")
add_cflags("--opt-code-size")
add_cflags("--xram-loc "..xram_loc)
set_kind("binary")
add_files("src/**/*.c", "src/main.c")

set_values(
    "ldflags", 
    "-mmcs51",
    "--model-small", 
    "--out-fmt-ihx", 
    "--xram-size "..xram_size,
    "--iram-size "..iram_size,
    "--code-size "..code_size,
    "--opt-code-size",
    "--xram-loc "..xram_loc
)

before_build(function (target)
    local commit_hash, err1 = os.iorun("git rev-parse --short HEAD")
    local timestamp, err2 = os.iorun("git log -1 --format=%ct")
    local formatted_time = "\"" .. os.date("%Y%m%d%H", tonumber(timestamp)) .. "\"" 
    local formatted_commit_hash = "\"" .. commit_hash .. "\""
    target:add("defines", "FIRMVERSION = "..formatted_time, "COMMIT_HASH = "..formatted_commit_hash)
end
)

on_link(function (target)
    local obj_files = target:objectfiles()
    local main_rel = target:objectdir() .. "/src/main.c.rel"
    os.run("mkdir -p ".. target:targetdir())

    -- 从中间文件中剔除main
    for i, file in ipairs(obj_files) do
        if file == main_rel then
            table.remove(obj_files, i)
            break
        end
    end
    -- end

    -- 从剔除了main的中间文件中创建单一静态库，便于sdcc做体积优化
    local bundle_path = target:objectdir() .. "/src/bundled.lib"
    os.run("sdar -rc %s %s ", bundle_path, table.concat(obj_files, " "))
    --

    -- 链接main和静态库
    local flags = target:values("ldflags")
    os.run("sdcc %s -o %s %s %s", table.concat(flags, " "), target:targetfile(), main_rel, bundle_path)
    --

    -- 创建hex
    local file = io.open(target:targetfile()..".hex", "w")
    if file then
        os.execv("packihx", {target:targetfile()}, {stdout = file})
        file:close()
    end
    --
end
)