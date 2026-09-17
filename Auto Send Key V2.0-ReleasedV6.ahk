#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; ==================================================
; 配置文件
; ==================================================

configPath := A_ScriptDir . "\random_content_config.ini"

; ==================================================
; 默认配置
; ==================================================

defaultGroupCount := 2
defaultMinInterval := 1200
defaultMaxInterval := 2000
defaultMaxActions := 50
defaultGroupOrderMode := "按组顺序"

defaultGroups := [
    ["a", "s", "d", "f", "j", "k", "l"],
    ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
]

defaultGroupModes := ["顺序", "顺序"]

; ==================================================
; 当前配置
; ==================================================

groupCount := defaultGroupCount
intervalMin := defaultMinInterval
intervalMax := defaultMaxInterval
maxActions := defaultMaxActions
groupOrderMode := defaultGroupOrderMode

groupModes := defaultGroupModes.Clone()
contentGroups := CloneGroups(defaultGroups)

; 程序状态：
; notStarted = 未开始
; running    = 运行中
; paused     = 已暂停
state := "notStarted"

settingsConfirmed := false
runCounter := 0

; 使用固定数组保存每组的顺序游标
groupCursors := [0, 0, 0, 0, 0]

; 控制面板控件
runtimeGui := ""
statusText := ""
counterText := ""
startBtn := ""
pauseBtn := ""
continueBtn := ""
stopBtn := ""


; ==================================================
; 启动
; ==================================================

LoadConfigFromFile()
BuildSetupWindow()


; ==================================================
; F6：开始 / 暂停 / 继续
; ==================================================

F6::
{
    global state
    global settingsConfirmed

    if !settingsConfirmed
        return

    if state = "notStarted"
    {
        StartProgram()
        return
    }

    if state = "running"
    {
        PauseProgram()
        return
    }

    if state = "paused"
    {
        ResumeProgram()
    }
}


; ==================================================
; F7：结束程序
; ==================================================

F7::
{
    global state

    result := MsgBox(
        "是否结束程序？",
        "结束确认",
        "YesNo Icon?"
    )

    if result = "Yes"
    {
        SetTimer NextAction, 0
        ExitApp
    }
}


; ==================================================
; 主循环
; ==================================================

NextAction()
{
    global state
    global groupCount
    global contentGroups
    global groupModes
    global groupCursors
    global runCounter
    global maxActions
    global intervalMin
    global intervalMax

    if state != "running"
        return

    if maxActions > 0 && runCounter >= maxActions
    {
        StopProgram()
        return
    }

    executionOrder := GetGroupExecutionOrder()

    for _, groupIndex in executionOrder
    {
        if state != "running"
            return

        if maxActions > 0 && runCounter >= maxActions
        {
            StopProgram()
            return
        }

        currentGroup := contentGroups[groupIndex]

        if currentGroup.Length = 0
            continue

        currentMode := groupModes[groupIndex]

        content := GetNextContentForGroup(
            groupIndex,
            currentMode
        )

        SendContent(content)

        Sleep 100
        Send "{Enter}"

        runCounter += 1
        UpdateCounterText()

        if maxActions > 0 && runCounter >= maxActions
        {
            Sleep 200
            StopProgram()
            return
        }

        ; 所有组统一使用最小～最大随机间隔
        Sleep Random(intervalMin, intervalMax)
    }

    if state = "running"
        SetTimer NextAction, -1
}


; ==================================================
; 获取组执行顺序
; ==================================================

GetGroupExecutionOrder()
{
    global groupCount
    global groupOrderMode

    executionOrder := []

    Loop groupCount
        executionOrder.Push(A_Index)

    if groupOrderMode = "随机组顺序"
        Shuffle(executionOrder)

    return executionOrder
}


; ==================================================
; 获取指定组的下一个内容
; ==================================================

GetNextContentForGroup(groupIndex, mode)
{
    global contentGroups
    global groupCursors

    ; 强制转换为数字索引
    groupIndex := Integer(groupIndex)

    group := contentGroups[groupIndex]

    if group.Length = 0
        return ""

    ; 顺序循环模式
    if mode = "顺序"
    {
        currentCursor := groupCursors[groupIndex]

        ; 防止游标越界
        if currentCursor < 0
            currentCursor := 0

        if currentCursor >= group.Length
            currentCursor := 0

        value := group[currentCursor + 1]

        ; 更新游标
        groupCursors[groupIndex] :=
            Mod(currentCursor + 1, group.Length)

        return value
    }

    ; 随机模式
    return group[Random(1, group.Length)]
}


; ==================================================
; 数组随机打乱
; ==================================================

Shuffle(array)
{
    itemCount := array.Length

    if itemCount < 2
        return array

    Loop itemCount - 1
    {
        currentIndex := A_Index
        randomIndex := Random(currentIndex + 1, itemCount)

        temporary := array[currentIndex]
        array[currentIndex] := array[randomIndex]
        array[randomIndex] := temporary
    }

    return array
}


; ==================================================
; 发送内容
; ==================================================

SendContent(content)
{
    content := Trim(content)
    lowerContent := StrLower(content)

    ; 组合键
    if lowerContent = "ctrl+v"
    {
        Send "^v"
        return
    }

    if lowerContent = "ctrl+c"
    {
        Send "^c"
        return
    }

    if lowerContent = "ctrl+x"
    {
        Send "^x"
        return
    }

    if lowerContent = "ctrl+a"
    {
        Send "^a"
        return
    }

    if lowerContent = "alt+tab"
    {
        Send "!{Tab}"
        return
    }

    if lowerContent = "shift+tab"
    {
        Send "+{Tab}"
        return
    }

    ; 常用特殊按键
    specialKeys := Map(
        "space", "{Space}",
        "tab", "{Tab}",
        "enter", "{Enter}",
        "backspace", "{Backspace}",
        "delete", "{Delete}",
        "insert", "{Insert}",
        "esc", "{Esc}",
        "escape", "{Esc}",
        "up", "{Up}",
        "down", "{Down}",
        "left", "{Left}",
        "right", "{Right}",
        "home", "{Home}",
        "end", "{End}",
        "pageup", "{PgUp}",
        "pagedown", "{PgDn}",
        "pgup", "{PgUp}",
        "pgdn", "{PgDn}",
        "printscreen", "{PrintScreen}",
        "pause", "{Pause}"
    )

    if specialKeys.Has(lowerContent)
    {
        Send specialKeys[lowerContent]
        return
    }

    ; F1～F12
    if RegExMatch(lowerContent, "^f([1-9]|1[0-2])$")
    {
        Send "{" . lowerContent . "}"
        return
    }

    ; 普通文本和符号
    SendText content
}


; ==================================================
; 开始程序
; ==================================================

StartProgram()
{
    global state
    global settingsConfirmed
    global runCounter
    global groupCursors

    if !settingsConfirmed
        return

    state := "running"
    runCounter := 0

    ; 重置所有组的顺序游标
    groupCursors := [0, 0, 0, 0, 0]

    SetTimer NextAction, -1

    UpdateStatusText()
    UpdateCounterText()
    UpdateRuntimeButtons()
}


; ==================================================
; 暂停程序
; ==================================================

PauseProgram()
{
    global state

    if state != "running"
        return

    state := "paused"

    SetTimer NextAction, 0

    UpdateStatusText()
    UpdateRuntimeButtons()
}


; ==================================================
; 继续程序
; ==================================================

ResumeProgram()
{
    global state

    if state != "paused"
        return

    state := "running"

    SetTimer NextAction, -1

    UpdateStatusText()
    UpdateRuntimeButtons()
}


; ==================================================
; 停止程序
; ==================================================

StopProgram()
{
    global state
    global runCounter
    global groupCursors

    state := "notStarted"
    runCounter := 0

    ; 停止后重置所有组的顺序游标
    groupCursors := [0, 0, 0, 0, 0]

    SetTimer NextAction, 0

    UpdateStatusText()
    UpdateCounterText()
    UpdateRuntimeButtons()
}


; ==================================================
; 创建运行控制面板
; ==================================================

BuildRuntimeWindow()
{
    global runtimeGui
    global statusText
    global counterText
    global startBtn
    global pauseBtn
    global continueBtn
    global stopBtn

    if IsObject(runtimeGui)
    {
        try
        {
            if runtimeGui.Hwnd
                return
        }
    }

    runtimeGui := Gui(
        "+AlwaysOnTop +ToolWindow",
        "随机内容发送工具"
    )

    runtimeGui.BackColor := "F3F6FA"
    runtimeGui.SetFont(
        "s10",
        "Microsoft YaHei"
    )

    runtimeGui.AddText(
        "x20 y18 w340 Center c1F2937",
        "随机内容发送工具"
    )

    statusText := runtimeGui.AddText(
        "x20 y55 w340 Center c4B5563",
        "状态：未开始"
    )

    counterText := runtimeGui.AddText(
        "x20 y78 w340 Center c6B7280",
        "执行次数：0"
    )

    startBtn := runtimeGui.AddButton(
        "x20 y115 w95 h36",
        "开始"
    )

    pauseBtn := runtimeGui.AddButton(
        "x125 y115 w95 h36",
        "暂停"
    )

    continueBtn := runtimeGui.AddButton(
        "x230 y115 w95 h36",
        "继续"
    )

    stopBtn := runtimeGui.AddButton(
        "x20 y165 w305 h38",
        "停止程序"
    )

    startBtn.OnEvent(
        "Click",
        (*) => StartProgram()
    )

    pauseBtn.OnEvent(
        "Click",
        (*) => PauseProgram()
    )

    continueBtn.OnEvent(
        "Click",
        (*) => ResumeProgram()
    )

    stopBtn.OnEvent(
        "Click",
        (*) => StopProgram()
    )

    runtimeGui.OnEvent(
        "Close",
        (*) => ExitApp()
    )

    UpdateStatusText()
    UpdateCounterText()
    UpdateRuntimeButtons()

    runtimeGui.Show("w365 h225 Center")
}


; ==================================================
; 更新状态文字
; ==================================================

UpdateStatusText()
{
    global statusText
    global state

    if !IsObject(statusText)
        return

    status := "状态：未开始"

    if state = "running"
        status := "状态：运行中"
    else if state = "paused"
        status := "状态：已暂停"

    statusText.Text := status
}


; ==================================================
; 更新执行次数
; ==================================================

UpdateCounterText()
{
    global counterText
    global runCounter
    global maxActions

    if !IsObject(counterText)
        return

    if maxActions > 0
    {
        counterText.Text :=
            "执行次数：" . runCounter
            . " / " . maxActions
    }
    else
    {
        counterText.Text :=
            "执行次数：" . runCounter . " / 无限"
    }
}


; ==================================================
; 更新按钮状态
; ==================================================

UpdateRuntimeButtons()
{
    global state
    global startBtn
    global pauseBtn
    global continueBtn
    global stopBtn

    if !IsObject(startBtn)
        return

    startBtn.Enabled := (state = "notStarted")
    pauseBtn.Enabled := (state = "running")
    continueBtn.Enabled := (state = "paused")
    stopBtn.Enabled := (state != "notStarted")
}


; ==================================================
; 创建设置窗口
; ==================================================

BuildSetupWindow()
{
    global groupCount
    global intervalMin
    global intervalMax
    global maxActions
    global groupOrderMode
    global contentGroups
    global groupModes
    global settingsConfirmed

    settingsConfirmed := false

    setupGui := Gui(
        "+AlwaysOnTop +ToolWindow",
        "随机内容发送工具 - 设置"
    )

    setupGui.BackColor := "FFFFFF"
    setupGui.SetFont(
        "s10",
        "Microsoft YaHei"
    )

    ; 标题单独使用大号粗体
    setupGui.SetFont(    
        "s16 Bold",    
        "Microsoft YaHei"
    )

    setupGui.AddText(    
        "x20 y14 w520 h30 Center c1F2937",    
        "随机内容发送工具"
    )

    ; 后续控件恢复为普通字体
    setupGui.SetFont(    
        "s10",    
        "Microsoft YaHei"
    )

    setupGui.AddText(
        "x20 y48 w520 c4B5563",
        "设置内容组、发送顺序和随机时间间隔"
    )

    ; ----------------------------------------------
    ; 整轮组顺序
    ; ----------------------------------------------

    setupGui.AddText(
        "x20 y82 w115 c374151",
        "整轮组顺序："
    )

    ; 缩短下拉框，避免遮挡后方控件
    groupOrderDrop := setupGui.AddDropDownList(
        "x140 y78 w108",
        ["按组顺序", "随机组顺序"]
    )

    if groupOrderMode = "随机组顺序"
        groupOrderDrop.Choose(2)
    else
        groupOrderDrop.Choose(1)

    ; ----------------------------------------------
    ; 组数量
    ; ----------------------------------------------

    setupGui.AddText(
        "x265 y82 w105 c374151",
        "内容组数量："
    )

    groupCountDrop := setupGui.AddDropDownList(
        "x370 y78 w65",
        ["1", "2", "3", "4", "5"]
    )

    groupCountDrop.Choose(groupCount)

    ; ----------------------------------------------
    ; 最小、最大间隔
    ; ----------------------------------------------

    setupGui.AddText(
        "x20 y120 w105 c374151",
        "最小间隔："
    )

    minEdit := setupGui.AddEdit(
        "x140 y116 w90",
        intervalMin
    )

    setupGui.AddText(
        "x265 y120 w105 c374151",
        "最大间隔："
    )

    maxEdit := setupGui.AddEdit(
        "x370 y116 w90",
        intervalMax
    )

    setupGui.AddText(
        "x20 y150 w520 c6B7280",
        "单位：毫秒。所有内容发送后，都会在该范围内随机等待。"
    )

    ; ----------------------------------------------
    ; 总执行次数
    ; ----------------------------------------------

    setupGui.AddText(
        "x20 y180 w115 c374151",
        "执行次数上限："
    )

    maxActionsEdit := setupGui.AddEdit(
        "x140 y176 w90",
        maxActions
    )

    setupGui.AddText(
        "x265 y180 w270 c6B7280",
        "填写 0 表示无限循环。"
    )

    ; ----------------------------------------------
    ; 内容组
    ; ----------------------------------------------

    groupEdits := []
    groupModeDrops := []

    yPosition := 218

    Loop 5
    {
        index := A_Index

        setupGui.AddText(
            "x20 y" . yPosition . " w72 c374151",
            "第 " . index . " 组"
        )

        modeDrop := setupGui.AddDropDownList(
            "x92 y" . (yPosition - 4) . " w78",
            ["顺序", "随机"]
        )

        if index <= groupModes.Length
        {
            if groupModes[index] = "随机"
                modeDrop.Choose(2)
            else
                modeDrop.Choose(1)
        }
        else
        {
            modeDrop.Choose(1)
        }

        groupModeDrops.Push(modeDrop)

        contentText := ""

        if index <= contentGroups.Length
        {
            contentText := FormatContentForDisplay(
                contentGroups[index]
            )
        }

        contentEdit := setupGui.AddEdit(
            "x180 y" . (yPosition - 4)
            . " w355 h36",
            contentText
        )

        groupEdits.Push(contentEdit)
        yPosition += 52
    }

    setupGui.AddText(
        "x20 y485 w520 c6B7280",
        "每组最多 10 个内容，使用英文逗号分隔。"
    )

    setupGui.AddText(
        "x20 y508 w520 c6B7280",
        "示例：a, s, d, Space, F1, Ctrl+V, &"
    )

    setupGui.AddText(
        "x20 y531 w520 c9CA3AF",
        "配置会自动保存到 random_content_config.ini"
    )

    ; ----------------------------------------------
    ; 操作按钮
    ; ----------------------------------------------

    saveBtn := setupGui.AddButton(
        "x20 y565 w120 h36",
        "保存设置"
    )

    defaultBtn := setupGui.AddButton(
        "x160 y565 w120 h36",
        "恢复默认"
    )

    cancelBtn := setupGui.AddButton(
        "x300 y565 w100 h36",
        "取消"
    )

    saveBtn.OnEvent(
        "Click",
        (*) => ConfirmAndSave(
            setupGui,
            groupOrderDrop,
            groupCountDrop,
            minEdit,
            maxEdit,
            maxActionsEdit,
            groupModeDrops,
            groupEdits
        )
    )

    defaultBtn.OnEvent(
        "Click",
        (*) => RestoreDefaults(
            groupOrderDrop,
            groupCountDrop,
            minEdit,
            maxEdit,
            maxActionsEdit,
            groupModeDrops,
            groupEdits
        )
    )

    cancelBtn.OnEvent(
        "Click",
        (*) => CancelSetup(setupGui)
    )

    setupGui.OnEvent(
        "Close",
        (*) => CancelSetup(setupGui)
    )

    setupGui.Show("w560 h615 Center")

    WinWaitClose(
        "ahk_id " . setupGui.Hwnd
    )

    if !settingsConfirmed
        ExitApp

    BuildRuntimeWindow()
}


; ==================================================
; 保存并检查设置
; ==================================================

ConfirmAndSave(
    setupGui,
    groupOrderDrop,
    groupCountDrop,
    minEdit,
    maxEdit,
    maxActionsEdit,
    groupModeDrops,
    groupEdits
)
{
    global groupCount
    global intervalMin
    global intervalMax
    global maxActions
    global contentGroups
    global groupModes
    global groupOrderMode
    global settingsConfirmed

    groupOrderMode := groupOrderDrop.Text

    if groupOrderMode != "按组顺序"
        && groupOrderMode != "随机组顺序"
    {
        groupOrderMode := "按组顺序"
    }

    try
    {
        newGroupCount := Integer(
            Trim(groupCountDrop.Text)
        )
    }
    catch
    {
        MsgBox(
            "内容组数量必须是 1～5。",
            "输入错误",
            "IconError"
        )
        return
    }

    if newGroupCount < 1 || newGroupCount > 5
    {
        MsgBox(
            "内容组数量必须是 1～5。",
            "输入错误",
            "IconError"
        )
        return
    }

    try
    {
        newMin := Integer(
            Trim(minEdit.Value)
        )

        newMax := Integer(
            Trim(maxEdit.Value)
        )
    }
    catch
    {
        MsgBox(
            "最小和最大间隔必须是有效整数。",
            "输入错误",
            "IconError"
        )
        return
    }

    if newMin < 1 || newMax < 1
    {
        MsgBox(
            "时间间隔必须大于 0。",
            "输入错误",
            "IconError"
        )
        return
    }

    if newMin > newMax
    {
        MsgBox(
            "最小间隔不能大于最大间隔。",
            "输入错误",
            "IconError"
        )
        return
    }

    try
    {
        newMaxActions := Integer(
            Trim(maxActionsEdit.Value)
        )
    }
    catch
    {
        MsgBox(
            "执行次数必须是整数。",
            "输入错误",
            "IconError"
        )
        return
    }

    if newMaxActions < 0
    {
        MsgBox(
            "执行次数不能小于 0。",
            "输入错误",
            "IconError"
        )
        return
    }

    newGroups := []
    newModes := []

    Loop newGroupCount
    {
        index := A_Index
        modeText := groupModeDrops[index].Text

        if modeText != "顺序" && modeText != "随机"
            modeText := "顺序"

        try
        {
            parsedGroup := ParseContent(
                groupEdits[index].Value
            )
        }
        catch as error
        {
            MsgBox(
                "第 " . index . " 组内容错误：`n`n"
                . error.Message,
                "输入错误",
                "IconError"
            )
            return
        }

        newGroups.Push(parsedGroup)
        newModes.Push(modeText)
    }

    groupCount := newGroupCount
    intervalMin := newMin
    intervalMax := newMax
    maxActions := newMaxActions
    contentGroups := newGroups
    groupModes := newModes
    settingsConfirmed := true

    SaveConfigToFile()

    setupGui.Destroy()
}


; ==================================================
; 恢复默认设置
; ==================================================

RestoreDefaults(
    groupOrderDrop,
    groupCountDrop,
    minEdit,
    maxEdit,
    maxActionsEdit,
    groupModeDrops,
    groupEdits
)
{
    global defaultGroupCount
    global defaultMinInterval
    global defaultMaxInterval
    global defaultMaxActions
    global defaultGroupOrderMode
    global defaultGroupModes
    global defaultGroups

    if defaultGroupOrderMode = "随机组顺序"
        groupOrderDrop.Choose(2)
    else
        groupOrderDrop.Choose(1)

    groupCountDrop.Choose(defaultGroupCount)
    minEdit.Value := defaultMinInterval
    maxEdit.Value := defaultMaxInterval
    maxActionsEdit.Value := defaultMaxActions

    Loop 5
    {
        index := A_Index

        if index <= defaultGroupModes.Length
        {
            if defaultGroupModes[index] = "随机"
                groupModeDrops[index].Choose(2)
            else
                groupModeDrops[index].Choose(1)
        }
        else
        {
            groupModeDrops[index].Choose(1)
        }

        if index <= defaultGroups.Length
        {
            groupEdits[index].Value :=
                FormatContentForDisplay(
                    defaultGroups[index]
                )
        }
        else
        {
            groupEdits[index].Value := ""
        }
    }
}


; ==================================================
; 取消设置
; ==================================================

CancelSetup(setupGui)
{
    global settingsConfirmed

    settingsConfirmed := false
    setupGui.Destroy()
}


; ==================================================
; 解析内容
; ==================================================

ParseContent(text)
{
    text := Trim(text)

    ; 支持：
    ; a, s, d
    ; "a", "s", "d"
    ; (a, s, d)
    ; ("a", "s", "d")

    if StrLen(text) >= 2
    {
        if SubStr(text, 1, 1) = "("
            && SubStr(text, -1) = ")"
        {
            text := Trim(
                SubStr(
                    text,
                    2,
                    StrLen(text) - 2
                )
            )
        }
    }

    if text = ""
        throw Error("内容不能为空。")

    rawItems := StrSplit(text, ",")
    result := []

    for rawItem in rawItems
    {
        item := Trim(rawItem)

        ; 去除每项外层英文双引号
        if StrLen(item) >= 2
        {
            if SubStr(item, 1, 1) = Chr(34)
                && SubStr(item, -1) = Chr(34)
            {
                item := SubStr(
                    item,
                    2,
                    StrLen(item) - 2
                )
            }
        }

        item := Trim(item)

        if item = ""
            throw Error(
                "不能包含空内容，请检查逗号分隔格式。"
            )

        result.Push(item)
    }

    if result.Length > 10
        throw Error(
            "每组最多只能设置 10 个内容。"
        )

    return result
}


; ==================================================
; 格式化内容
;
; 不自动添加双引号，避免重复双引号
; ==================================================

FormatContentForDisplay(contents)
{
    output := ""

    for index, item in contents
    {
        item := Trim(item)

        ; 清理旧配置遗留的外层双引号
        if StrLen(item) >= 2
        {
            if SubStr(item, 1, 1) = Chr(34)
                && SubStr(item, -1) = Chr(34)
            {
                item := SubStr(
                    item,
                    2,
                    StrLen(item) - 2
                )
            }
        }

        if index > 1
            output .= ", "

        output .= item
    }

    return output
}


; ==================================================
; 深度复制内容组
; ==================================================

CloneGroups(groups)
{
    result := []

    for group in groups
        result.Push(group.Clone())

    return result
}


; ==================================================
; 保存 INI 配置
; ==================================================

SaveConfigToFile()
{
    global configPath
    global groupCount
    global intervalMin
    global intervalMax
    global maxActions
    global groupOrderMode
    global contentGroups
    global groupModes

    IniWrite(
        groupCount,
        configPath,
        "Settings",
        "group_count"
    )

    IniWrite(
        intervalMin,
        configPath,
        "Settings",
        "min_interval"
    )

    IniWrite(
        intervalMax,
        configPath,
        "Settings",
        "max_interval"
    )

    IniWrite(
        maxActions,
        configPath,
        "Settings",
        "max_actions"
    )

    IniWrite(
        groupOrderMode,
        configPath,
        "Settings",
        "group_order_mode"
    )

    Loop groupCount
    {
        index := A_Index

        IniWrite(
            groupModes[index],
            configPath,
            "Groups",
            "group_mode_" . index
        )

        IniWrite(
            FormatContentForDisplay(
                contentGroups[index]
            ),
            configPath,
            "Groups",
            "group_" . index
        )
    }
}


; ==================================================
; 加载 INI 配置
; ==================================================

LoadConfigFromFile()
{
    global configPath
    global groupCount
    global intervalMin
    global intervalMax
    global maxActions
    global groupOrderMode
    global contentGroups
    global groupModes

    global defaultGroupCount
    global defaultMinInterval
    global defaultMaxInterval
    global defaultMaxActions
    global defaultGroupOrderMode

    if !FileExist(configPath)
        return

    savedGroupCount := IniRead(
        configPath,
        "Settings",
        "group_count",
        defaultGroupCount
    )

    savedMin := IniRead(
        configPath,
        "Settings",
        "min_interval",
        defaultMinInterval
    )

    savedMax := IniRead(
        configPath,
        "Settings",
        "max_interval",
        defaultMaxInterval
    )

    savedMaxActions := IniRead(
        configPath,
        "Settings",
        "max_actions",
        defaultMaxActions
    )

    savedOrderMode := IniRead(
        configPath,
        "Settings",
        "group_order_mode",
        defaultGroupOrderMode
    )

    try
    {
        newGroupCount := Integer(
            Trim(savedGroupCount)
        )

        newMin := Integer(
            Trim(savedMin)
        )

        newMax := Integer(
            Trim(savedMax)
        )

        newMaxActions := Integer(
            Trim(savedMaxActions)
        )
    }
    catch
    {
        return
    }

    if newGroupCount < 1 || newGroupCount > 5
        return

    if newMin < 1 || newMax < 1
        return

    if newMin > newMax
        return

    if newMaxActions < 0
        return

    if savedOrderMode != "按组顺序"
        && savedOrderMode != "随机组顺序"
    {
        savedOrderMode := defaultGroupOrderMode
    }

    newGroups := []
    newModes := []

    Loop newGroupCount
    {
        index := A_Index

        savedMode := IniRead(
            configPath,
            "Groups",
            "group_mode_" . index,
            "顺序"
        )

        savedText := IniRead(
            configPath,
            "Groups",
            "group_" . index,
            ""
        )

        if savedMode != "顺序"
            && savedMode != "随机"
        {
            savedMode := "顺序"
        }

        try
        {
            parsedGroup := ParseContent(savedText)
        }
        catch
        {
            return
        }

        if parsedGroup.Length < 1
            return

        if parsedGroup.Length > 10
            return

        newGroups.Push(parsedGroup)
        newModes.Push(savedMode)
    }

    groupCount := newGroupCount
    intervalMin := newMin
    intervalMax := newMax
    maxActions := newMaxActions
    groupOrderMode := savedOrderMode
    contentGroups := newGroups
    groupModes := newModes
}