name = "阿比盖尔三形态切换"
description = [[

移除月晷切换阿比盖尔形态的月相限制，可自定义是否保留夜晚限制。

添加按O键切换到月亮形态，再次按下切换到暗影形态（非强化版）

添加按L键切换到暗影强化形态的功能 

添加一个新的计时器来管理强化状态的持续时间。

添加了冷却时间系统

添加了不同时间的属性系统

]]
author = "Va6gn"
version = "1.2"

-- API版本
api_version = 10

-- mod图标
icon_atlas = "modicon.xml"
icon = "modicon.tex"

-- mod类型
dst_compatible = true
client_only_mod = false
all_clients_require_mod = true

configuration_options = {
    {
        name = "enable_night_check",
        label = "Enable Night Check",
        options = {
            {description = "Yes", data = "yes"},
            {description = "No", data = "no"},
        },
        default = "yes",
    },
}