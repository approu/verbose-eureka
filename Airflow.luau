local Airflow = {}
Airflow.Version = "1.5"

if _G and _G.__AIRFLOW_LIB then
        return _G.__AIRFLOW_LIB
end

local tween_service = game:GetService("TweenService")
local user_input = game:GetService("UserInputService")
local players = game:GetService("Players")
local lighting = game:GetService("Lighting")

local function clamp(value, min, max)
        if value < min then
                return min
        end
        if value > max then
                return max
        end
        return value
end

local function in_list(list, value)
        for i = 1, #list do
                if list[i] == value then
                        return true
                end
        end
        return false
end

local C = {
        White = Color3.fromRGB(255, 255, 255),
        Gray = Color3.fromRGB(150, 150, 150),
        DarkGray = Color3.fromRGB(120, 120, 120),
        Border = Color3.fromRGB(100, 100, 100),
        Item = Color3.fromRGB(217, 217, 217),
        ItemHover = Color3.fromRGB(255, 255, 255),
        KnobOuter = Color3.fromRGB(75, 75, 75),
        Danger = Color3.fromRGB(255, 80, 80),
}

local T_ITEM = 0.922
local T_ITEM_HOVER = 0.804
local T_INNER = 0.686
local T_LINE = 0.95
local T_LABEL = 0.5

local FONT_TITLE = Enum.Font.GothamSemibold
local FONT_MED = Enum.Font.GothamMedium
local FONT_REG = Enum.Font.Gotham

local HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MOVE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local function make(class, props, parent)
        local inst = Instance.new(class)
        if props then
                for key, value in pairs(props) do
                        inst[key] = value
                end
        end
        if parent then
                inst.Parent = parent
        end
        return inst
end

local function rounded(inst, radius)
        make("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
        return inst
end

local function stroke_of(inst, color, transparency, thickness)
        return make("UIStroke", {
                Color = color,
                Transparency = transparency,
                Thickness = thickness or 1,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, inst)
end

local function tween_obj(inst, props, info)
        local t = tween_service:Create(inst, info or HOVER_INFO, props)
        t:Play()
        return t
end

local function hoverize(btn, on_base, off_base, color_base)
        local base_t = on_base or T_ITEM
        local hover_t = off_base or T_ITEM_HOVER
        btn.MouseEnter:Connect(function()
                tween_obj(btn, { BackgroundTransparency = hover_t, BackgroundColor3 = C.ItemHover })
        end)
        btn.MouseLeave:Connect(function()
                tween_obj(btn, { BackgroundTransparency = base_t, BackgroundColor3 = color_base or C.Item })
        end)
end

local function protect_gui(gui)
        local attached = pcall(function()
                if type(gethui) == "function" then
                        gui.Parent = gethui()
                elseif syn and syn.protect_gui then
                        syn.protect_gui(gui)
                        gui.Parent = game:GetService("CoreGui")
                else
                        gui.Parent = game:GetService("CoreGui")
                end
        end)
        if not attached or gui.Parent == nil then
                local lp = players.LocalPlayer
                if lp then
                        gui.Parent = lp:WaitForChild("PlayerGui")
                else
                        gui.Parent = game:GetService("CoreGui")
                end
        end
end

local add_tab_impl, add_subtab_impl, add_groupbox_impl
local add_checkbox_impl, add_slider_impl, add_button_impl, add_label_impl, add_divider_impl
local add_dropdown_impl, add_multi_impl, add_textbox_impl, add_keybind_impl, add_color_impl, add_listbox_impl

local function resolve_args(first, second)
        if type(first) == "table" then
                return first
        end
        return second
end

Airflow.CreateWindow = function(config)
        config = config or {}

        local window = {}
        window._accent = { color = config.Accent or config.Theme or Color3.fromRGB(255, 76, 25) }
        window._accented = {}
        window._conns = {}
        window._tabs = {}
        window._keybind_listeners = {}
        window._popups = {}
        window.Opened = false
        window.Title = config.Title or config.Name or "airflow"
        window.ToggleKey = config.ToggleKey or Enum.KeyCode.RightControl

        local screen = make("ScreenGui", {
                Name = tostring(config.Name or "airflow"),
                ResetOnSpawn = false,
                IgnoreGuiInset = true,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                DisplayOrder = 9999,
                Enabled = false,
        })
        window._screen = screen

        local ok_canvas = pcall(function()
                local g = Instance.new("CanvasGroup")
                g:Destroy()
        end)

        local main
        if ok_canvas then
                main = make("CanvasGroup", {
                        Size = UDim2.fromOffset(720, 520),
                        Position = UDim2.fromScale(0.5, 0.5),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        GroupTransparency = 1,
                }, screen)
        else
                main = make("Frame", {
                        Size = UDim2.fromOffset(720, 520),
                        Position = UDim2.fromScale(0.5, 0.5),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                }, screen)
                window._fade_insts = {}
        end
        window._main = main
        window._has_group = ok_canvas
        window.Icon = config.Icon or nil

        local border_frame = make("Frame", {
                Size = UDim2.fromOffset(720, 520),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, main)
        rounded(border_frame, 6)
        window._border_stroke = stroke_of(border_frame, C.Border, 0.61, 1)

        local blur = nil
        if config.Blur ~= false then
                pcall(function()
                        blur = make("BlurEffect", { Size = 0 }, lighting)
                end)
        end
        window._blur = blur

        local body = make("Frame", {
                Size = UDim2.fromOffset(720, 473),
                Position = UDim2.fromOffset(0, 47),
                BackgroundColor3 = Color3.fromRGB(26, 26, 26),
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
        }, main)
        rounded(body, 6)
        make("Frame", {
                Size = UDim2.fromOffset(720, 6),
                Position = UDim2.fromOffset(0, 0),
                BackgroundColor3 = Color3.fromRGB(26, 26, 26),
                BackgroundTransparency = 0.12,
                BorderSizePixel = 0,
        }, body)

        local header = make("TextButton", {
                Size = UDim2.fromOffset(720, 47),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0.88,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, main)
        rounded(header, 6)
        make("Frame", {
                Size = UDim2.fromOffset(720, 6),
                Position = UDim2.fromOffset(0, 41),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0.88,
                BorderSizePixel = 0,
        }, header)

        make("Frame", {
                Size = UDim2.fromOffset(720, 1),
                Position = UDim2.fromOffset(0, 46),
                BackgroundColor3 = C.White,
                BackgroundTransparency = T_LINE,
                BorderSizePixel = 0,
        }, main)

        make("Frame", {
                Size = UDim2.fromOffset(1, 473),
                Position = UDim2.fromOffset(160, 47),
                BackgroundColor3 = C.White,
                BackgroundTransparency = T_LINE,
                BorderSizePixel = 0,
        }, main)

        local title_holder = make("Frame", {
                Size = UDim2.fromOffset(400, 47),
                Position = UDim2.fromOffset(160, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, main)
        local title_layout = make("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 16),
        }, title_holder)

        local icon = make("ImageLabel", {
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ImageColor3 = C.White,
                ImageTransparency = 0.41,
                Visible = false,
                LayoutOrder = 1,
        }, title_holder)

        local title_label = make("TextLabel", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_TITLE,
                Text = window.Title,
                TextSize = 16,
                TextColor3 = C.White,
                TextTransparency = 0.41,
                LayoutOrder = 2,
        }, title_holder)

        local popup_layer = make("TextButton", {
                Size = UDim2.fromOffset(720, 520),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Text = "",
                Visible = false,
                ZIndex = 50,
                AutoButtonColor = false,
        }, main)
        window._popup_layer = popup_layer

        local function refresh_title()
                title_label.Text = window.Title
                icon.Visible = window.Icon ~= nil and window.Icon ~= ""
                if window.Icon then
                        icon.Image = window.Icon
                end
        end
        window._refresh_title = refresh_title
        refresh_title()

        local content_holder = make("Frame", {
                Size = UDim2.fromOffset(540, 393),
                Position = UDim2.fromOffset(178, 124),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, main)
        window._content_holder = content_holder

        local function register_accent(inst, kind)
                table.insert(window._accented, { inst = inst, kind = kind })
        end
        window._register_accent = register_accent

        local function close_popups()
                for i = 1, #window._popups do
                        window._popups[i]:Destroy()
                end
                window._popups = {}
                popup_layer.Visible = false
        end
        window._close_popups = close_popups

        local function open_popup(frame)
                close_popups()
                table.insert(window._popups, frame)
                frame.Parent = popup_layer
                popup_layer.Visible = true
        end
        window._open_popup = open_popup

        popup_layer.MouseButton1Click:Connect(function()
                close_popups()
        end)

        local function acc_pos(inst)
                local ap = inst.AbsolutePosition
                local mp = main.AbsolutePosition
                return ap.X - mp.X, ap.Y - mp.Y
        end
        window._acc_pos = acc_pos

        local function set_opened(state, instant)
                if window.Opened == state then
                        return
                end
                window.Opened = state
                close_popups()
                screen.Enabled = true
                if window._has_group then
                        if instant then
                                main.GroupTransparency = state and 0 or 1
                        else
                                tween_obj(main, { GroupTransparency = state and 0 or 1 }, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
                        end
                else
                        main.Visible = state
                end
                if blur then
                        tween_obj(blur, { Size = state and 10 or 0 }, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
                end
        end
        window._set_opened = set_opened

        table.insert(window._conns, user_input.InputBegan:Connect(function(input, processed)
                if processed then
                        return
                end
                if input.KeyCode == window.ToggleKey then
                        set_opened(not window.Opened)
                        return
                end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if #window._popups > 0 then
                                close_popups()
                        end
                end
                if window.Opened then
                        for i = 1, #window._keybind_listeners do
                                local listener = window._keybind_listeners[i]
                                if listener.listening then
                                        if input.KeyCode == Enum.KeyCode.Escape then
                                                listener.listening = false
                                                listener.key = nil
                                                listener.update()
                                        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                                                listener.listening = false
                                                listener.key = input.KeyCode
                                                listener.update()
                                        end
                                        return
                                end
                        end
                        for i = 1, #window._keybind_listeners do
                                local listener = window._keybind_listeners[i]
                                if listener.key == input.KeyCode and listener.mode == "Toggle" then
                                        listener.value = not listener.value
                                        if listener.callback then
                                                listener.callback(listener.value)
                                        end
                                elseif listener.key == input.KeyCode and listener.mode == "Hold" and input.UserInputType == Enum.UserInputType.Keyboard then
                                        if listener.callback then
                                                listener.callback(true)
                                        end
                                end
                        end
                end
        end))

        table.insert(window._conns, user_input.InputEnded:Connect(function(input)
                if not window.Opened then
                        return
                end
                for i = 1, #window._keybind_listeners do
                        local listener = window._keybind_listeners[i]
                        if listener.key == input.KeyCode and listener.mode == "Hold" then
                                if listener.callback then
                                        listener.callback(false)
                                end
                        end
                end
        end))

        local drag_conn = nil
        header.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        local start_pos = input.Position
                        local start_main = main.Position
                        if drag_conn then
                                drag_conn:Disconnect()
                        end
                        drag_conn = user_input.InputChanged:Connect(function(move)
                                if move.UserInputType == Enum.UserInputType.MouseMovement or move.UserInputType == Enum.UserInputType.Touch then
                                        local dx = move.Position.X - start_pos.X
                                        local dy = move.Position.Y - start_pos.Y
                                        main.Position = UDim2.new(start_main.X.Scale, start_main.X.Offset + dx, start_main.Y.Scale, start_main.Y.Offset + dy)
                                end
                        end)
                        table.insert(window._conns, drag_conn)
                end
        end)
        header.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        if drag_conn then
                                drag_conn:Disconnect()
                                drag_conn = nil
                        end
                end
        end)

        function window.SetTitle(self, text)
                window.Title = tostring(text)
                refresh_title()
        end

        function window.SetIcon(self, image_id)
                if image_id == nil or image_id == "" then
                        window.Icon = nil
                else
                        window.Icon = tostring(image_id)
                end
                refresh_title()
        end

        function window.SetAccent(self, color)
                window._accent.color = color
                for i = 1, #window._accented do
                        local entry = window._accented[i]
                        if entry.kind == "bg" then
                                entry.inst.BackgroundColor3 = color
                        elseif entry.kind == "text" then
                                entry.inst.TextColor3 = color
                        elseif entry.kind == "grad" then
                                entry.inst.Color = ColorSequence.new(color)
                        elseif entry.kind == "img" then
                                entry.inst.ImageColor3 = color
                        elseif entry.kind == "stroke" then
                                entry.inst.Color = color
                        end
                end
        end

        function window.GetAccent(self)
                return window._accent.color
        end

        function window.SetKey(self, keycode)
                window.ToggleKey = keycode
        end

        function window.Toggle(self)
                set_opened(not window.Opened)
        end

        function window.Show(self)
                set_opened(true)
        end

        function window.Hide(self)
                set_opened(false)
        end

        window.AddTab = function(self, tab_config, icon)
                return add_tab_impl(window, resolve_args(tab_config, { Name = tab_config, Icon = icon }))
        end

        window.AddGroupbox = function(self, gb_config, side)
                local first_tab = window._tabs[1]
                return first_tab:AddGroupbox(gb_config, side)
        end

        window.GetTab = function(self, name)
                for i = 1, #window._tabs do
                        if window._tabs[i].Name == name then
                                return window._tabs[i]
                        end
                end
                return nil
        end

        window.Destroy = function(self)
                for i = 1, #window._conns do
                        pcall(function()
                                window._conns[i]:Disconnect()
                        end)
                end
                window._conns = {}
                if blur then
                        pcall(function()
                                blur:Destroy()
                        end)
                end
                pcall(function()
                        screen:Destroy()
                end)
                window.Destroyed = true
        end

        add_tab_impl(window, { Name = config.DefaultTab or "Main" })

        table.insert(Airflow._windows, window)

        screen.Parent = nil
        protect_gui(screen)

        if config.OpenOnStart ~= false then
                set_opened(true, true)
        else
                screen.Enabled = true
        end

        return window
end

local function make_column(window, x_offset)
        local scroll = make("ScrollingFrame", {
                Size = UDim2.fromOffset(256, 393),
                Position = UDim2.fromOffset(x_offset, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = C.White,
                ScrollBarImageTransparency = 0.7,
                CanvasSize = UDim2.fromOffset(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Visible = false,
        }, window._content_holder)
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 0),
        }, scroll)
        return scroll
end

add_tab_impl = function(window, tab_config)
        local tab = {
                Name = tab_config.Name or "Tab",
                Icon = tab_config.Icon,
                _subtabs = {},
                _current_subtab = nil,
                _selected = false,
                _index = #window._tabs + 1,
                _window = window,
        }
        tab._content = make("Frame", {
                Size = UDim2.fromOffset(540, 393),
                Position = UDim2.fromOffset(0, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Visible = false,
        }, window._content_holder)
        tab._col_left = make_column(window, 0)
        tab._col_right = make_column(window, 270)
        tab._col_left.Parent = tab._content
        tab._col_right.Parent = tab._content

        local tab_button = make("TextButton", {
                Size = UDim2.fromOffset(144, 32),
                Position = UDim2.fromOffset(8, 63 + 40 * (tab._index - 1)),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, window._main)
        tab._button = tab_button

        local tab_bg = make("Frame", {
                Size = UDim2.fromOffset(144, 32),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, tab_button)
        rounded(tab_bg, 4)
        tab._bg = tab_bg

        local tab_bar = make("Frame", {
                Size = UDim2.fromOffset(4, 28),
                Position = UDim2.fromOffset(140, 2),
                BackgroundColor3 = window._accent.color,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 2,
        }, tab_button)
        rounded(tab_bar, 2)
        window._register_accent(tab_bar, "bg")
        tab._bar = tab_bar

        local tab_icon = nil
        if tab.Icon then
                tab_icon = make("ImageLabel", {
                        Size = UDim2.fromOffset(15, 15),
                        Position = UDim2.fromOffset(10, 9),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Image = tab.Icon,
                        ImageColor3 = C.Gray,
                }, tab_button)
                tab._icon = tab_icon
        end

        local tab_text_x = 12
        if tab.Icon then
                tab_text_x = 32
        end
        local tab_label = make("TextLabel", {
                Size = UDim2.fromOffset(144 - tab_text_x - 4, 16),
                Position = UDim2.fromOffset(tab_text_x, 8),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = tab.Name,
                TextSize = 14,
                TextColor3 = C.Gray,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, tab_button)
        tab._label = tab_label

        local function select_tab()
                window._close_popups()
                for i = 1, #window._tabs do
                        local other = window._tabs[i]
                        other._selected = false
                        other._content.Visible = false
                        other._label.TextColor3 = C.Gray
                        if other._icon then
                                other._icon.ImageColor3 = C.Gray
                        end
                        tween_obj(other._bg, { BackgroundTransparency = 1 })
                        tween_obj(other._bar, { BackgroundTransparency = 1 })
                end
                tab._selected = true
                tab._content.Visible = true
                tab._label.TextColor3 = C.White
                if tab._icon then
                        tab._icon.ImageColor3 = C.White
                end
                tween_obj(tab._bg, { BackgroundTransparency = 0.96 })
                tween_obj(tab._bar, { BackgroundTransparency = 0 })
                if #tab._subtabs > 0 then
                        if not tab._current_subtab then
                                tab._subtabs[1]._select()
                        else
                                tab._current_subtab._select()
                        end
                end
        end
        tab._select = select_tab

        tab_button.MouseEnter:Connect(function()
                if not tab._selected then
                        tab._label.TextColor3 = C.White
                        if tab._icon then
                                tab._icon.ImageColor3 = C.White
                        end
                end
        end)
        tab_button.MouseLeave:Connect(function()
                if not tab._selected then
                        tab._label.TextColor3 = C.Gray
                        if tab._icon then
                                tab._icon.ImageColor3 = C.Gray
                        end
                end
        end)
        tab_button.MouseButton1Click:Connect(select_tab)

        function tab.Select(self)
                select_tab()
        end

        function tab.AddSubTab(self, sub_config)
                return add_subtab_impl(tab, resolve_args(sub_config, { Name = sub_config }))
        end

        function tab.AddGroupbox(self, gb_config, side)
                if #tab._subtabs == 0 then
                        tab:AddSubTab("General")
                end
                return tab._current_subtab:AddGroupbox(gb_config, side)
        end

        table.insert(window._tabs, tab)
        if tab._index == 1 then
                select_tab()
        end
        return tab
end

add_subtab_impl = function(tab, sub_config)
        local window = tab._window
        local sub = {
                Name = sub_config.Name or "Sub",
                _index = #tab._subtabs + 1,
                _groups = {},
        }
        sub._container = make("Frame", {
                Size = UDim2.fromOffset(540, 393),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Visible = false,
        }, tab._content)
        sub._left = make_column(window, 0)
        sub._left.Parent = sub._container
        sub._right = make_column(window, 270)
        sub._right.Parent = sub._container

        local panel = make("Frame", {
                Size = UDim2.fromOffset(528, 58),
                Position = UDim2.fromOffset(178, 62),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = 0.922,
                BorderSizePixel = 0,
        }, tab._content)
        rounded(panel, 4)
        sub._panel = panel

        local sub_button = make("TextButton", {
                Size = UDim2.fromOffset(70, 32),
                Position = UDim2.fromOffset(19 + 80 * (sub._index - 1), 14),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, panel)
        sub._button = sub_button

        local sub_bg = make("Frame", {
                Size = UDim2.fromOffset(70, 32),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, sub_button)
        rounded(sub_bg, 4)
        sub._bg = sub_bg

        local sub_underline = make("Frame", {
                Size = UDim2.fromOffset(40, 3),
                Position = UDim2.fromOffset(15, 30),
                BackgroundColor3 = window._accent.color,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 2,
        }, sub_button)
        rounded(sub_underline, 2)
        window._register_accent(sub_underline, "bg")
        sub._underline = sub_underline

        local sub_label = make("TextLabel", {
                Size = UDim2.fromOffset(70, 32),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = sub.Name,
                TextSize = 13,
                TextColor3 = C.Gray,
        }, sub_button)
        sub._label = sub_label

        local function select_sub()
                window._close_popups()
                for i = 1, #tab._subtabs do
                        local other = tab._subtabs[i]
                        other._container.Visible = false
                        other._label.TextColor3 = C.Gray
                        tween_obj(other._bg, { BackgroundTransparency = 1 })
                        tween_obj(other._underline, { BackgroundTransparency = 1 })
                end
                sub._container.Visible = true
                sub._label.TextColor3 = C.White
                tween_obj(sub._bg, { BackgroundTransparency = 0.922 })
                tween_obj(sub._underline, { BackgroundTransparency = 0 })
                tab._current_subtab = sub
        end
        sub._select = select_sub

        sub_button.MouseEnter:Connect(function()
                if tab._current_subtab ~= sub then
                        sub._label.TextColor3 = C.White
                end
        end)
        sub_button.MouseLeave:Connect(function()
                if tab._current_subtab ~= sub then
                        sub._label.TextColor3 = C.Gray
                end
        end)
        sub_button.MouseButton1Click:Connect(select_sub)

        function sub.AddGroupbox(self, gb_config, side)
                return add_groupbox_impl(tab, sub, resolve_args(gb_config, { Name = gb_config, Side = side }))
        end

        table.insert(tab._subtabs, sub)
        if sub._index == 1 then
                select_sub()
        end
        return sub
end

local function groupbox_column(sub, side)
        if side == "right" or side == 2 then
                return sub._right
        end
        return sub._left
end

add_groupbox_impl = function(tab, sub, gb_config)
        local window = tab._window
        local gb = {
                Name = gb_config.Name or "Groupbox",
                _elements = {},
        }
        local order = #sub._left:GetChildren() + #sub._right:GetChildren() + 1
        local holder = make("Frame", {
                Size = UDim2.fromOffset(256, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = order,
        }, groupbox_column(sub, gb_config.Side))
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
        }, holder)
        gb._holder = holder

        local title = make("TextLabel", {
                Size = UDim2.fromOffset(256, 18),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = gb.Name,
                TextSize = 14,
                TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
        }, holder)
        gb._title = title

        local counter = 1
        local function next_order()
                counter = counter + 1
                return counter
        end
        gb._next_order = next_order

        function gb.AddCheckbox(self, name, default, callback)
                local cfg = resolve_args(name, { Name = name, Default = default, Callback = callback })
                return add_checkbox_impl(window, gb, cfg)
        end

        function gb.AddSlider(self, name, min_value, max_value, default, callback)
                local cfg = resolve_args(name, { Name = name, Min = min_value, Max = max_value, Default = default, Callback = callback })
                return add_slider_impl(window, gb, cfg)
        end

        function gb.AddButton(self, name, callback)
                local cfg = resolve_args(name, { Name = name, Callback = callback })
                return add_button_impl(window, gb, cfg)
        end

        function gb.AddLabel(self, text)
                local cfg = resolve_args(text, { Text = text })
                return add_label_impl(window, gb, cfg)
        end

        function gb.AddDivider(self)
                return add_divider_impl(window, gb, {})
        end

        function gb.AddDropdown(self, name, items, default, callback)
                local cfg = resolve_args(name, { Name = name, Items = items, Default = default, Callback = callback })
                return add_dropdown_impl(window, gb, cfg)
        end

        function gb.AddMultiDropdown(self, name, items, defaults, callback)
                local cfg = resolve_args(name, { Name = name, Items = items, Default = defaults, Callback = callback })
                return add_multi_impl(window, gb, cfg)
        end

        function gb.AddTextbox(self, name, default, callback, placeholder)
                local cfg = resolve_args(name, { Name = name, Default = default, Callback = callback, Placeholder = placeholder })
                return add_textbox_impl(window, gb, cfg)
        end

        function gb.AddKeybind(self, name, default_key, callback, mode)
                local cfg = resolve_args(name, { Name = name, Default = default_key, Callback = callback, Mode = mode })
                return add_keybind_impl(window, gb, cfg)
        end

        function gb.AddColorPicker(self, name, default, callback, has_alpha)
                local cfg = resolve_args(name, { Name = name, Default = default, Callback = callback, Alpha = has_alpha })
                return add_color_impl(window, gb, cfg)
        end

        function gb.AddListbox(self, name, items, callback, max_visible)
                local cfg = resolve_args(name, { Name = name, Items = items, Callback = callback, MaxVisible = max_visible })
                return add_listbox_impl(window, gb, cfg)
        end

        return gb
end

add_checkbox_impl = function(window, gb, cfg)
        local state = cfg.Default == true
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 36),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("TextButton", {
                Size = UDim2.fromOffset(256, 32),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, row)
        rounded(bg, 4)
        hoverize(bg)

        local label = make("TextLabel", {
                Size = UDim2.fromOffset(200, 18),
                Position = UDim2.fromOffset(12, 7),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Checkbox",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local pill = make("Frame", {
                Size = UDim2.fromOffset(28, 14),
                Position = UDim2.fromOffset(220, 9),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = T_INNER,
                BorderSizePixel = 0,
        }, bg)
        rounded(pill, 7)

        local knob = make("Frame", {
                Size = UDim2.fromOffset(8, 8),
                Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = window._accent.color,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 2,
        }, pill)
        rounded(knob, 4)
        window._register_accent(knob, "bg")

        local obj = {}

        local function render(instant)
                local target_x = state and 17 or 3
                local target_t = state and 0 or 1
                if instant then
                        knob.Position = UDim2.fromOffset(target_x, 3)
                        knob.BackgroundTransparency = target_t
                else
                        tween_obj(knob, { Position = UDim2.fromOffset(target_x, 3), BackgroundTransparency = target_t }, MOVE_INFO)
                end
        end

        local function set_value(value, silent)
                state = value == true
                render(false)
                if not silent and cfg.Callback then
                        cfg.Callback(state)
                end
        end

        bg.MouseButton1Click:Connect(function()
                set_value(not state)
        end)

        function obj.Set(self, value)
                set_value(value, true)
        end

        function obj.Get(self)
                return state
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end

        set_value(state, true)
        return obj
end

add_slider_impl = function(window, gb, cfg)
        local min_value = cfg.Min or 0
        local max_value = cfg.Max or 100
        local is_float = type(min_value) ~= "number" or math.floor(min_value) ~= min_value or math.floor(max_value) ~= max_value or (cfg.Step and cfg.Step < 1)
        local value = cfg.Default or min_value
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 60),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("TextButton", {
                Size = UDim2.fromOffset(256, 56),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, row)
        rounded(bg, 4)
        hoverize(bg)

        local label = make("TextLabel", {
                Size = UDim2.fromOffset(180, 16),
                Position = UDim2.fromOffset(12, 9),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Slider",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local value_label = make("TextLabel", {
                Size = UDim2.fromOffset(120, 16),
                Position = UDim2.fromOffset(124, 9),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = tostring(value),
                TextSize = 14,
                TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Right,
        }, bg)

        local bar = make("Frame", {
                Size = UDim2.fromOffset(232, 24),
                Position = UDim2.fromOffset(12, 28),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = T_INNER,
                BorderSizePixel = 0,
        }, bg)
        rounded(bar, 3)

        local fill = make("Frame", {
                Size = UDim2.fromOffset(6, 6),
                Position = UDim2.fromOffset(0, 9),
                BackgroundColor3 = window._accent.color,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 2,
        }, bar)
        rounded(fill, 4)
        local fill_gradient = make("UIGradient", {
                Color = ColorSequence.new(window._accent.color),
                Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.5),
                        NumberSequenceKeypoint.new(1, 0),
                }),
                Rotation = 0,
        }, fill)
        window._register_accent(fill, "bg")
        window._register_accent(fill_gradient, "grad")

        local knob_outer = make("Frame", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.fromOffset(0, 4),
                BackgroundColor3 = C.KnobOuter,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 3,
        }, bar)
        rounded(knob_outer, 8)
        local knob_inner = make("Frame", {
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.fromOffset(3, 3),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 4,
        }, knob_outer)
        rounded(knob_inner, 5)

        local obj = {}

        local function format_number(v)
                if is_float then
                        return string.format("%.2f", v)
                end
                return string.format("%d", math.floor(v + 0.5))
        end

        local function render(instant)
                local progress = clamp((value - min_value) / (max_value - min_value), 0, 1)
                local fill_w = math.floor(6 + progress * 226)
                local knob_x = math.floor(progress * 216)
                value_label.Text = format_number(value)
                local props = {
                        Size = UDim2.fromOffset(fill_w, 6),
                }
                local knob_props = {
                        Position = UDim2.fromOffset(knob_x, 4),
                }
                if instant then
                        fill.Size = props.Size
                        knob_outer.Position = knob_props.Position
                else
                        tween_obj(fill, props, MOVE_INFO)
                        tween_obj(knob_outer, knob_props, MOVE_INFO)
                end
        end

        local function set_value(new_value, silent)
                if not is_float then
                        new_value = math.floor(new_value + 0.5)
                end
                value = clamp(new_value, min_value, max_value)
                render(false)
                if not silent and cfg.Callback then
                        cfg.Callback(value)
                end
        end

        local dragging = false

        local function update_from_input(input)
                local bar_abs = bar.AbsolutePosition
                local rel_x = input.Position.X - bar_abs.X
                local progress = clamp(rel_x / 232, 0, 1)
                local new_value = min_value + (max_value - min_value) * progress
                if not is_float then
                        new_value = math.floor(new_value + 0.5)
                end
                value = new_value
                render(false)
                if cfg.Callback then
                        cfg.Callback(value)
                end
        end

        bg.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        update_from_input(input)
                end
        end)

        table.insert(window._conns, user_input.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        update_from_input(input)
                end
        end))

        table.insert(window._conns, user_input.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                end
        end))

        function obj.Set(self, new_value)
                set_value(new_value, true)
        end

        function obj.Get(self)
                return value
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end

        render(true)
        return obj
end

add_button_impl = function(window, gb, cfg)
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 36),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local btn = make("TextButton", {
                Size = UDim2.fromOffset(256, 32),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Button",
                TextSize = 14,
                TextColor3 = cfg.Danger and C.Danger or C.White,
                AutoButtonColor = false,
        }, row)
        rounded(btn, 4)
        hoverize(btn)

        btn.MouseButton1Click:Connect(function()
                if cfg.Callback then
                        cfg.Callback()
                end
        end)

        local obj = {}
        function obj.SetName(self, text)
                btn.Text = tostring(text)
        end
        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end
        return obj
end

add_label_impl = function(window, gb, cfg)
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)
        local text_label = make("TextLabel", {
                Size = UDim2.fromOffset(256, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_REG,
                Text = cfg.Text or cfg.Name or "Label",
                TextSize = 14,
                TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
        }, row)
        local obj = {}
        function obj.SetText(self, text)
                text_label.Text = tostring(text)
        end
        return obj
end

add_divider_impl = function(window, gb, cfg)
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 13),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)
        make("Frame", {
                Size = UDim2.fromOffset(256, 1),
                Position = UDim2.fromOffset(0, 6),
                BackgroundColor3 = C.White,
                BackgroundTransparency = T_LINE,
                BorderSizePixel = 0,
        }, row)
        local obj = {}
        return obj
end

local function key_name(keycode)
        if keycode == nil then
                return "None"
        end
        local name = tostring(keycode.Name)
        return name
end

local function build_dropdown_popup(window, gb, anchor_frame, width, height, on_build)
        local popup = make("Frame", {
                Size = UDim2.fromOffset(width, height),
                BackgroundColor3 = C.Popup or Color3.fromRGB(5, 5, 5),
                BackgroundTransparency = 0.08,
                BorderSizePixel = 0,
                ZIndex = 51,
        }, nil)
        rounded(popup, 4)
        make("Frame", {
                Size = UDim2.fromOffset(width, 4),
                Position = UDim2.fromOffset(0, height - 4),
                BackgroundColor3 = C.Popup or Color3.fromRGB(5, 5, 5),
                BackgroundTransparency = 0.08,
                BorderSizePixel = 0,
                ZIndex = 52,
        }, popup)
        local list = make("ScrollingFrame", {
                Size = UDim2.fromOffset(width, height),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = C.White,
                ScrollBarImageTransparency = 0.7,
                CanvasSize = UDim2.fromOffset(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ZIndex = 53,
        }, popup)
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
        }, list)
        on_build(list)
        local ax, ay = window._acc_pos(anchor_frame)
        popup.Position = UDim2.fromOffset(ax, ay + anchor_frame.AbsoluteSize.Y + 4)
        window._open_popup(popup)
        return popup
end

add_dropdown_impl = function(window, gb, cfg)
        local items = cfg.Items or {}
        local value = cfg.Default
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 52),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("TextButton", {
                Size = UDim2.fromOffset(256, 48),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, row)
        rounded(bg, 4)

        local label = make("TextLabel", {
                Size = UDim2.fromOffset(150, 16),
                Position = UDim2.fromOffset(12, 16),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Dropdown",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local value_label = make("TextLabel", {
                Size = UDim2.fromOffset(100, 16),
                Position = UDim2.fromOffset(116, 16),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = value or "...",
                TextSize = 14,
                TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
        }, bg)

        local arrow_l = make("Frame", {
                Size = UDim2.fromOffset(1, 7),
                Position = UDim2.fromOffset(236, 21),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Rotation = 45,
                ZIndex = 2,
        }, bg)
        make("Frame", {
                Size = UDim2.fromOffset(1, 7),
                Position = UDim2.fromOffset(241, 21),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Rotation = -45,
                ZIndex = 2,
        }, bg)

        local inner = make("Frame", {
                Size = UDim2.fromOffset(123, 31),
                Position = UDim2.fromOffset(126, 9),
                BackgroundColor3 = Color3.fromRGB(5, 5, 5),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 1,
        }, bg)
        rounded(inner, 4)
        local inner_sep = make("Frame", {
                Size = UDim2.fromOffset(121, 1),
                Position = UDim2.fromOffset(1, 30),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 2,
        }, inner)

        local obj = {}

        local function refresh_value()
                value_label.Text = value or "..."
        end

        local function toggle_popup()
                if obj._open then
                        window._close_popups()
                        obj._open = false
                        tween_obj(inner, { BackgroundTransparency = 1 })
                        tween_obj(inner_sep, { BackgroundTransparency = 1 })
                        return
                end
                window._close_popups()
                obj._open = true
                local popup_height = clamp(#items * 22 + 8, 30, 200)
                build_dropdown_popup(window, gb, inner, 123, popup_height, function(list)
                        for i = 1, #items do
                                local item_value = items[i]
                                local item_btn = make("TextButton", {
                                        Size = UDim2.fromOffset(123, 22),
                                        BackgroundColor3 = C.White,
                                        BackgroundTransparency = 1,
                                        BorderSizePixel = 0,
                                        Font = FONT_MED,
                                        Text = tostring(item_value),
                                        TextSize = 13,
                                        TextColor3 = item_value == value and C.White or C.Gray,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                        ZIndex = 54,
                                        LayoutOrder = i,
                                }, list)
                                item_btn.MouseEnter:Connect(function()
                                        item_btn.BackgroundTransparency = 0.92
                                end)
                                item_btn.MouseLeave:Connect(function()
                                        item_btn.BackgroundTransparency = 1
                                end)
                                item_btn.MouseButton1Click:Connect(function()
                                        value = item_value
                                        refresh_value()
                                        obj._open = false
                                        window._close_popups()
                                        tween_obj(inner, { BackgroundTransparency = 1 })
                                        if cfg.Callback then
                                                cfg.Callback(value)
                                        end
                                end)
                        end
                end)
                tween_obj(inner, { BackgroundTransparency = T_INNER })
                tween_obj(inner_sep, { BackgroundTransparency = T_LINE })
        end

        bg.MouseButton1Click:Connect(toggle_popup)

        function obj.Set(self, new_value)
                value = new_value
                refresh_value()
        end

        function obj.Get(self)
                return value
        end

        function obj.Refresh(self, new_items, keep_value)
                items = new_items or {}
                if not keep_value or not in_list(items, value) then
                        value = items[1]
                end
                refresh_value()
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end

        refresh_value()
        return obj
end

add_multi_impl = function(window, gb, cfg)
        local items = cfg.Items or {}
        local selected = {}
        if type(cfg.Default) == "table" then
                for i = 1, #cfg.Default do
                        selected[cfg.Default[i]] = true
                end
        end
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 52),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("TextButton", {
                Size = UDim2.fromOffset(256, 48),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, row)
        rounded(bg, 4)

        make("TextLabel", {
                Size = UDim2.fromOffset(150, 16),
                Position = UDim2.fromOffset(12, 16),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Multi",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local value_label = make("TextLabel", {
                Size = UDim2.fromOffset(100, 16),
                Position = UDim2.fromOffset(116, 16),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = "...",
                TextSize = 14,
                TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
        }, bg)

        make("Frame", {
                Size = UDim2.fromOffset(1, 7),
                Position = UDim2.fromOffset(236, 21),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Rotation = 45,
        }, bg)
        make("Frame", {
                Size = UDim2.fromOffset(1, 7),
                Position = UDim2.fromOffset(241, 21),
                BackgroundColor3 = C.White,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Rotation = -45,
        }, bg)

        local obj = {}

        local function selected_list()
                local out = {}
                for i = 1, #items do
                        if selected[items[i]] then
                                table.insert(out, items[i])
                        end
                end
                return out
        end

        local function refresh_value()
                local list = selected_list()
                if #list == 0 then
                        value_label.Text = "..."
                else
                        value_label.Text = table.concat(list, ", ")
                end
        end

        local function fire()
                if cfg.Callback then
                        cfg.Callback(selected_list())
                end
        end

        local function toggle_popup()
                if obj._open then
                        window._close_popups()
                        obj._open = false
                        return
                end
                window._close_popups()
                obj._open = true
                local popup_height = clamp(#items * 26 + 8, 34, 200)
                build_dropdown_popup(window, gb, value_label, 123, popup_height, function(list)
                        for i = 1, #items do
                                local item_value = items[i]
                                local item_btn = make("TextButton", {
                                        Size = UDim2.fromOffset(123, 26),
                                        BackgroundColor3 = C.White,
                                        BackgroundTransparency = 1,
                                        BorderSizePixel = 0,
                                        Text = "",
                                        ZIndex = 54,
                                        LayoutOrder = i,
                                }, list)
                                item_btn.MouseEnter:Connect(function()
                                        item_btn.BackgroundTransparency = 0.92
                                end)
                                item_btn.MouseLeave:Connect(function()
                                        item_btn.BackgroundTransparency = 1
                                end)
                                local mark = make("Frame", {
                                        Size = UDim2.fromOffset(14, 14),
                                        Position = UDim2.fromOffset(7, 6),
                                        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                                        BackgroundTransparency = T_INNER,
                                        BorderSizePixel = 0,
                                        ZIndex = 55,
                                }, item_btn)
                                rounded(mark, 3)
                                local mark_fill = make("Frame", {
                                        Size = UDim2.fromOffset(14, 14),
                                        BackgroundColor3 = window._accent.color,
                                        BackgroundTransparency = selected[item_value] and 0 or 1,
                                        BorderSizePixel = 0,
                                        ZIndex = 56,
                                }, mark)
                                rounded(mark_fill, 3)
                                window._register_accent(mark_fill, "bg")
                                make("TextLabel", {
                                        Size = UDim2.fromOffset(90, 26),
                                        Position = UDim2.fromOffset(28, 0),
                                        BackgroundTransparency = 1,
                                        BorderSizePixel = 0,
                                        Font = FONT_MED,
                                        Text = tostring(item_value),
                                        TextSize = 13,
                                        TextColor3 = C.White,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                        ZIndex = 55,
                                }, item_btn)
                                item_btn.MouseButton1Click:Connect(function()
                                        selected[item_value] = not selected[item_value] and true or nil
                                        mark_fill.BackgroundTransparency = selected[item_value] and 0 or 1
                                        refresh_value()
                                        fire()
                                end)
                        end
                end)
        end

        bg.MouseButton1Click:Connect(toggle_popup)

        function obj.Set(self, new_list)
                selected = {}
                if type(new_list) == "table" then
                        for i = 1, #new_list do
                                selected[new_list[i]] = true
                        end
                end
                refresh_value()
        end

        function obj.Get(self)
                return selected_list()
        end

        function obj.Refresh(self, new_items, keep)
                items = new_items or {}
                if not keep then
                        selected = {}
                end
                refresh_value()
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end

        refresh_value()
        return obj
end

add_textbox_impl = function(window, gb, cfg)
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 52),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("Frame", {
                Size = UDim2.fromOffset(256, 48),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
        }, row)
        rounded(bg, 4)

        local label = make("TextLabel", {
                Size = UDim2.fromOffset(232, 16),
                Position = UDim2.fromOffset(12, 7),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Textbox",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local box = make("TextBox", {
                Size = UDim2.fromOffset(232, 18),
                Position = UDim2.fromOffset(12, 25),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Default or "",
                TextSize = 14,
                TextColor3 = C.White,
                PlaceholderText = cfg.Placeholder or "...",
                PlaceholderColor3 = C.DarkGray,
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local underline = make("Frame", {
                Size = UDim2.fromOffset(232, 2),
                Position = UDim2.fromOffset(12, 45),
                BackgroundColor3 = window._accent.color,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, bg)
        window._register_accent(underline, "bg")

        box.Focused:Connect(function()
                tween_obj(underline, { BackgroundTransparency = 0 })
        end)

        box.FocusLost:Connect(function(enter)
                tween_obj(underline, { BackgroundTransparency = 1 })
                if cfg.Callback then
                        cfg.Callback(box.Text, enter == true)
                end
        end)

        local obj = {}
        function obj.Set(self, text)
                box.Text = tostring(text)
        end
        function obj.Get(self)
                return box.Text
        end
        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end
        return obj
end

add_keybind_impl = function(window, gb, cfg)
        local mode = cfg.Mode or "Toggle"
        local key = cfg.Default
        local listening = false
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 36),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("TextButton", {
                Size = UDim2.fromOffset(256, 32),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, row)
        rounded(bg, 4)

        make("TextLabel", {
                Size = UDim2.fromOffset(160, 18),
                Position = UDim2.fromOffset(12, 7),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Keybind",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local frame_box = make("TextButton", {
                Size = UDim2.fromOffset(71, 18),
                Position = UDim2.fromOffset(185, 7),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0.686,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = key_name(key),
                TextSize = 11,
                TextColor3 = C.White,
                AutoButtonColor = false,
                ZIndex = 2,
        }, bg)
        rounded(frame_box, 4)

        local obj = {
                value = false,
        }

        local function refresh_text()
                if listening then
                        frame_box.Text = "..."
                        frame_box.TextColor3 = window._accent.color
                else
                        frame_box.Text = key_name(key)
                        frame_box.TextColor3 = C.White
                end
        end

        local listener = {
                listening = false,
                key = key,
                mode = mode,
                callback = cfg.Callback,
                value = false,
                update = refresh_text,
        }

        function listener.fire(state)
                if cfg.Callback then
                        cfg.Callback(state)
                end
        end

        table.insert(window._keybind_listeners, listener)

        frame_box.MouseButton1Click:Connect(function()
                listening = not listening
                listener.listening = listening
                refresh_text()
        end)

        frame_box.MouseButton2Click:Connect(function()
                window._close_popups()
                local popup_height = 3 * 22 + 8
                build_dropdown_popup(window, gb, frame_box, 71, popup_height, function(list)
                        local modes = { "Always", "Hold", "Toggle" }
                        for i = 1, #modes do
                                local mode_name = modes[i]
                                local item_btn = make("TextButton", {
                                        Size = UDim2.fromOffset(71, 22),
                                        BackgroundColor3 = C.White,
                                        BackgroundTransparency = 1,
                                        BorderSizePixel = 0,
                                        Font = FONT_MED,
                                        Text = mode_name,
                                        TextSize = 12,
                                        TextColor3 = mode_name == mode and C.White or C.Gray,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                        ZIndex = 54,
                                        LayoutOrder = i,
                                }, list)
                                item_btn.MouseEnter:Connect(function()
                                        item_btn.BackgroundTransparency = 0.92
                                end)
                                item_btn.MouseLeave:Connect(function()
                                        item_btn.BackgroundTransparency = 1
                                end)
                                item_btn.MouseButton1Click:Connect(function()
                                        mode = mode_name
                                        listener.mode = mode_name
                                        window._close_popups()
                                end)
                        end
                end)
        end)

        function obj.SetKey(self, new_key)
                key = new_key
                listener.key = new_key
                refresh_text()
        end

        function obj.GetKey(self)
                return key
        end

        function obj.SetMode(self, new_mode)
                mode = new_mode
                listener.mode = new_mode
        end

        function obj.GetMode(self)
                return mode
        end

        function obj.IsActive(self)
                return listener.value
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
                listener.callback = cb
        end

        refresh_text()
        return obj
end

add_color_impl = function(window, gb, cfg)
        local has_alpha = cfg.Alpha == true
        local color = cfg.Default or Color3.fromRGB(255, 255, 255)
        local alpha = 1
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 36),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local bg = make("TextButton", {
                Size = UDim2.fromOffset(256, 32),
                BackgroundColor3 = C.Item,
                BackgroundTransparency = T_ITEM,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
        }, row)
        rounded(bg, 4)

        make("TextLabel", {
                Size = UDim2.fromOffset(180, 18),
                Position = UDim2.fromOffset(12, 7),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "Color",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, bg)

        local swatch = make("Frame", {
                Size = UDim2.fromOffset(28, 14),
                Position = UDim2.fromOffset(220, 9),
                BackgroundColor3 = color,
                BackgroundTransparency = 1 - alpha,
                BorderSizePixel = 0,
                ZIndex = 2,
        }, bg)
        rounded(swatch, 7)
        local swatch_stroke = stroke_of(swatch, C.White, T_INNER, 1)

        local hsv = { h = 0, s = 0, v = 1 }
        pcall(function()
                local h, s, v = color:ToHSV()
                hsv.h, hsv.s, hsv.v = h, s, v
        end)

        local obj = {}

        local function fire()
                if cfg.Callback then
                        if has_alpha then
                                cfg.Callback(color, alpha)
                        else
                                cfg.Callback(color)
                        end
                end
        end

        local function render(instant)
                swatch.BackgroundColor3 = color
                swatch.BackgroundTransparency = clamp(1 - alpha, 0, 1)
        end

        local function build_popup()
                window._close_popups()
                local popup = make("Frame", {
                        Size = UDim2.fromOffset(196, has_alpha and 208 or 192),
                        BackgroundColor3 = Color3.fromRGB(5, 5, 5),
                        BackgroundTransparency = 0.08,
                        BorderSizePixel = 0,
                        ZIndex = 51,
                }, nil)
                rounded(popup, 4)

                local sv = make("Frame", {
                        Size = UDim2.fromOffset(172, 110),
                        Position = UDim2.fromOffset(12, 12),
                        BackgroundColor3 = Color3.fromHSV(hsv.h, 1, 1),
                        BorderSizePixel = 0,
                        ZIndex = 52,
                }, popup)
                rounded(sv, 4)
                local white_layer = make("Frame", {
                        Size = UDim2.fromOffset(172, 110),
                        BackgroundColor3 = C.White,
                        BorderSizePixel = 0,
                        ZIndex = 53,
                }, sv)
                rounded(white_layer, 4)
                make("UIGradient", {
                        Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0),
                                NumberSequenceKeypoint.new(1, 1),
                        }),
                        Rotation = 0,
                }, white_layer)
                local black_layer = make("Frame", {
                        Size = UDim2.fromOffset(172, 110),
                        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        ZIndex = 54,
                }, sv)
                rounded(black_layer, 4)
                make("UIGradient", {
                        Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 1),
                                NumberSequenceKeypoint.new(1, 0),
                        }),
                        Rotation = 90,
                }, black_layer)
                local sv_cursor = make("Frame", {
                        Size = UDim2.fromOffset(8, 8),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromOffset(hsv.s * 172, (1 - hsv.v) * 110),
                        BackgroundColor3 = C.White,
                        BorderSizePixel = 0,
                        ZIndex = 55,
                }, sv)
                rounded(sv_cursor, 4)
                local sv_stroke = stroke_of(sv_cursor, Color3.fromRGB(0, 0, 0), 0.4, 1)

                local hue = make("Frame", {
                        Size = UDim2.fromOffset(172, 12),
                        Position = UDim2.fromOffset(12, 130),
                        BackgroundColor3 = C.White,
                        BorderSizePixel = 0,
                        ZIndex = 52,
                }, popup)
                rounded(hue, 4)
                make("UIGradient", {
                        Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                                ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                                ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                                ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                        }),
                }, hue)
                local hue_cursor = make("Frame", {
                        Size = UDim2.fromOffset(3, 12),
                        Position = UDim2.fromOffset(hsv.h * 169, 0),
                        BackgroundColor3 = C.White,
                        BorderSizePixel = 0,
                        ZIndex = 53,
                }, hue)

                local alpha_bar = nil
                local alpha_cursor = nil
                if has_alpha then
                        alpha_bar = make("Frame", {
                                Size = UDim2.fromOffset(172, 12),
                                Position = UDim2.fromOffset(12, 148),
                                BackgroundColor3 = color,
                                BorderSizePixel = 0,
                                ZIndex = 52,
                        }, popup)
                        rounded(alpha_bar, 4)
                        make("UIGradient", {
                                Transparency = NumberSequence.new({
                                        NumberSequenceKeypoint.new(0, 0),
                                        NumberSequenceKeypoint.new(1, 1),
                                }),
                        }, alpha_bar)
                        alpha_cursor = make("Frame", {
                                Size = UDim2.fromOffset(3, 12),
                                Position = UDim2.fromOffset(alpha * 169, 0),
                                BackgroundColor3 = C.White,
                                BorderSizePixel = 0,
                                ZIndex = 53,
                        }, alpha_bar)
                end

                local preview = make("Frame", {
                        Size = UDim2.fromOffset(172, 16),
                        Position = UDim2.fromOffset(12, has_alpha and 166 or 148),
                        BackgroundColor3 = color,
                        BackgroundTransparency = clamp(1 - alpha, 0, 1),
                        BorderSizePixel = 0,
                        ZIndex = 52,
                }, popup)
                rounded(preview, 4)
                local preview_text = make("TextLabel", {
                        Size = UDim2.fromOffset(172, 16),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Font = FONT_MED,
                        Text = string.format("%d, %d, %d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5)),
                        TextSize = 12,
                        TextColor3 = C.White,
                        TextStrokeTransparency = 0.8,
                        ZIndex = 53,
                }, preview)

                local function update_color()
                        color = Color3.fromHSV(hsv.h, hsv.s, hsv.v)
                        sv.BackgroundColor3 = Color3.fromHSV(hsv.h, 1, 1)
                        if alpha_bar then
                                alpha_bar.BackgroundColor3 = color
                        end
                        preview.BackgroundColor3 = color
                        preview.BackgroundTransparency = clamp(1 - alpha, 0, 1)
                        preview_text.Text = string.format("%d, %d, %d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
                        render(false)
                        fire()
                end

                sv.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                hsv.s = clamp((input.Position.X - sv.AbsolutePosition.X) / 172, 0, 1)
                                hsv.v = clamp(1 - (input.Position.Y - sv.AbsolutePosition.Y) / 110, 0, 1)
                                sv_cursor.Position = UDim2.fromOffset(hsv.s * 172, (1 - hsv.v) * 110)
                                update_color()
                        end
                end)
                hue.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                hsv.h = clamp((input.Position.X - hue.AbsolutePosition.X) / 172, 0, 0.999)
                                hue_cursor.Position = UDim2.fromOffset(hsv.h * 169, 0)
                                update_color()
                        end
                end)
                if alpha_bar then
                        alpha_bar.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                        alpha = clamp((input.Position.X - alpha_bar.AbsolutePosition.X) / 172, 0, 1)
                                        alpha_cursor.Position = UDim2.fromOffset(alpha * 169, 0)
                                        update_color()
                                end
                        end)
                end

        local drag_active = false
        local active_target = nil
        local function on_persistent_input_changed(input)
                if not drag_active or active_target == nil then
                        return
                end
                if sv.Parent == nil or hue.Parent == nil then
                        drag_active = false
                        active_target = nil
                        return
                end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
                        return
                end
                if active_target == "sv" then
                        hsv.s = clamp((input.Position.X - sv.AbsolutePosition.X) / 172, 0, 1)
                        hsv.v = clamp(1 - (input.Position.Y - sv.AbsolutePosition.Y) / 110, 0, 1)
                        sv_cursor.Position = UDim2.fromOffset(hsv.s * 172, (1 - hsv.v) * 110)
                        update_color()
                elseif active_target == "hue" then
                        hsv.h = clamp((input.Position.X - hue.AbsolutePosition.X) / 172, 0, 0.999)
                        hue_cursor.Position = UDim2.fromOffset(hsv.h * 169, 0)
                        update_color()
                elseif active_target == "alpha" and alpha_bar then
                        alpha = clamp((input.Position.X - alpha_bar.AbsolutePosition.X) / 172, 0, 1)
                        alpha_cursor.Position = UDim2.fromOffset(alpha * 169, 0)
                        update_color()
                end
        end

        table.insert(window._conns, user_input.InputChanged:Connect(on_persistent_input_changed))

        table.insert(window._conns, user_input.InputEnded:Connect(function()
                drag_active = false
                active_target = nil
        end))

                sv.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                drag_active = true
                                active_target = "sv"
                        end
                end)
                hue.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                drag_active = true
                                active_target = "hue"
                        end
                end)
                if alpha_bar then
                        alpha_bar.InputBegan:Connect(function(input)
                                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                        drag_active = true
                                        active_target = "alpha"
                                end
                        end)
                end

                local ax, ay = window._acc_pos(swatch)
                popup.Position = UDim2.fromOffset(clamp(ax - 84, 4, 720 - 200), ay + 22)
                window._open_popup(popup)
        end

        bg.MouseButton1Click:Connect(build_popup)

        function obj.Set(self, new_color, new_alpha)
                color = new_color
                if new_alpha ~= nil then
                        alpha = new_alpha
                end
                pcall(function()
                        local h, s, v = color:ToHSV()
                        hsv.h, hsv.s, hsv.v = h, s, v
                end)
                render(false)
        end

        function obj.Get(self)
                return color, alpha
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end

        render(true)
        return obj
end

add_listbox_impl = function(window, gb, cfg)
        local items = cfg.Items or {}
        local selected_index = 0
        local max_visible = cfg.MaxVisible or 5
        local row = make("Frame", {
                Size = UDim2.fromOffset(256, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = gb._next_order(),
        }, gb._holder)

        local label = make("TextLabel", {
                Size = UDim2.fromOffset(256, 18),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_MED,
                Text = cfg.Name or "List",
                TextSize = 14,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
        }, row)

        local box_height = clamp(#items, 1, max_visible) * 22 + 4
        local box = make("ScrollingFrame", {
                Size = UDim2.fromOffset(256, box_height),
                Position = UDim2.fromOffset(0, 22),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = T_INNER,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = C.White,
                ScrollBarImageTransparency = 0.7,
                CanvasSize = UDim2.fromOffset(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
        }, row)
        rounded(box, 4)
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
        }, box)

        local obj = {}

        local function rebuild()
                for _, child in pairs(box:GetChildren()) do
                        if child:IsA("TextButton") then
                                child:Destroy()
                        end
                end
                for i = 1, #items do
                        local idx = i
                        local item_btn = make("TextButton", {
                                Size = UDim2.fromOffset(256, 22),
                                BackgroundColor3 = C.White,
                                BackgroundTransparency = 1,
                                BorderSizePixel = 0,
                                Font = FONT_MED,
                                Text = tostring(items[idx]),
                                TextSize = 13,
                                TextColor3 = idx == selected_index and C.White or C.Gray,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                LayoutOrder = idx,
                        }, box)
                        local bar = make("Frame", {
                                Size = UDim2.fromOffset(3, 22),
                                BackgroundColor3 = window._accent.color,
                                BackgroundTransparency = idx == selected_index and 0 or 1,
                                BorderSizePixel = 0,
                        }, item_btn)
                        window._register_accent(bar, "bg")
                        item_btn.MouseEnter:Connect(function()
                                item_btn.BackgroundTransparency = 0.92
                        end)
                        item_btn.MouseLeave:Connect(function()
                                item_btn.BackgroundTransparency = 1
                        end)
                        item_btn.MouseButton1Click:Connect(function()
                                selected_index = idx
                                obj:Refresh(items)
                                if cfg.Callback then
                                        cfg.Callback(items[idx], idx)
                                end
                        end)
                end
        end

        function obj.Set(self, new_items)
                items = new_items or {}
                selected_index = 0
                box.Size = UDim2.fromOffset(256, clamp(#items, 1, max_visible) * 22 + 4)
                rebuild()
        end

        function obj.Refresh(self, new_items)
                items = new_items or items
                rebuild()
        end

        function obj.Get(self)
                return items[selected_index], selected_index
        end

        function obj.SetCallback(self, cb)
                cfg.Callback = cb
        end

        rebuild()
        return obj
end

Airflow._windows = Airflow._windows or {}
Airflow._notifications = {}

local notif_screen = nil
local notif_holder = nil

local function ensure_notif_gui()
        if notif_screen ~= nil and notif_screen.Parent ~= nil then
                return
        end
        notif_screen = make("ScreenGui", {
                Name = "AirflowNotifications",
                ResetOnSpawn = false,
                IgnoreGuiInset = true,
                DisplayOrder = 10000,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        })
        notif_holder = make("Frame", {
                Size = UDim2.fromOffset(320, 600),
                Position = UDim2.new(1, -16, 0, 16),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, notif_screen)
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 8),
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
        }, notif_holder)
        protect_gui(notif_screen)
end

Airflow.Notify = function(cfg)
        cfg = cfg or {}
        local title_text = cfg.Title or "airflow"
        local body_text = cfg.Text or cfg.Description or ""
        local duration = cfg.Duration or 4

        ensure_notif_gui()

        local wrapper = make("Frame", {
                Size = UDim2.fromOffset(300, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, notif_holder)

        local card = make("Frame", {
                Size = UDim2.fromOffset(300, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Color3.fromRGB(24, 24, 24),
                BackgroundTransparency = 0.08,
                BorderSizePixel = 0,
        }, wrapper)
        rounded(card, 6)
        stroke_of(card, C.White, 0.92, 1)

        local accent_bar = make("Frame", {
                Size = UDim2.fromOffset(3, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Airflow._default_accent or Color3.fromRGB(255, 76, 25),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
        }, card)
        rounded(accent_bar, 3)

        local inner = make("Frame", {
                Size = UDim2.fromOffset(289, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.fromOffset(6, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
        }, card)
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 2),
        }, inner)

        local title_label = make("TextLabel", {
                Size = UDim2.fromOffset(285, 18),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_TITLE,
                Text = tostring(title_text),
                TextSize = 14,
                TextColor3 = C.White,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
        }, inner)

        local body_label = make("TextLabel", {
                Size = UDim2.fromOffset(285, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Font = FONT_REG,
                Text = tostring(body_text),
                TextSize = 13,
                TextColor3 = C.White,
                TextTransparency = T_LABEL,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                LayoutOrder = 2,
        }, inner)

        local pad = make("Frame", {
                Size = UDim2.fromOffset(1, 6),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                LayoutOrder = 3,
        }, inner)

        table.insert(Airflow._notifications, wrapper)

        card.Position = UDim2.fromOffset(340, 0)
        tween_service:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.fromOffset(0, 0),
        }):Play()

        task.delay(duration, function()
                local out = tween_service:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                        Position = UDim2.fromOffset(340, 0),
                })
                out:Play()
                task.wait(0.3)
                pcall(function()
                        wrapper:Destroy()
                end)
        end)

        local obj = {}
        function obj.Destroy(self)
                pcall(function()
                        card:Destroy()
                end)
        end
        return obj
end

Airflow.Unload = function()
        for i = 1, #Airflow._windows do
                local w = Airflow._windows[i]
                if w and not w.Destroyed then
                        pcall(function()
                                w:Destroy()
                        end)
                end
        end
        Airflow._windows = {}
        for i = 1, #Airflow._notifications do
                pcall(function()
                        Airflow._notifications[i]:Destroy()
                end)
        end
        Airflow._notifications = {}
        if notif_screen then
                pcall(function()
                        notif_screen:Destroy()
                end)
                notif_screen = nil
                notif_holder = nil
        end
        if _G then
                _G.__AIRFLOW_LIB = nil
        end
end

Airflow.GetWindow = function(name)
        for i = 1, #Airflow._windows do
                local w = Airflow._windows[i]
                if w and w._screen and w._screen.Name == name then
                        return w
                end
        end
        return nil
end

if _G then
        _G.__AIRFLOW_LIB = Airflow
end

return Airflow
