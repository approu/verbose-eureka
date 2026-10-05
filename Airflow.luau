local Airflow = {}
Airflow.Version = "2.0"
Airflow.Windows = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

local function get_global()
        local ok, g = pcall(function()
                return getgenv()
        end)
        if ok and g then
                return g
        end
        return _G
end

local G = get_global()

local function clamp(v, a, b)
        if v < a then
                return a
        end
        if v > b then
                return b
        end
        return v
end

local function lerp(a, b, t)
        return a + (b - a) * t
end

local function rgb(r, g, b)
        return Color3.fromRGB(r, g, b)
end

local function transp(alpha)
        return clamp(1 - alpha / 255, 0, 1)
end

local function rgb_hsv(r, g, b)
        r, g, b = r / 255, g / 255, b / 255
        local mx, mn = math.max(r, g, b), math.min(r, g, b)
        local d = mx - mn
        local h, s, v = 0, mx, mx
        if mx > 0 then
                s = d / mx
        end
        if d > 0 then
                if mx == r then
                        h = (g - b) / d
                elseif mx == g then
                        h = 2 + (b - r) / d
                else
                        h = 4 + (r - g) / d
                end
                h = h / 6
                if h < 0 then
                        h = h + 1
                end
        end
        return h, s, v
end

local function hsv_rgb(h, s, v)
        h = clamp(h, 0, 1) * 6
        local i = math.floor(h)
        local f = h - i
        local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
        local r, g, b
        if i == 0 then
                r, g, b = v, t, p
        elseif i == 1 then
                r, g, b = q, v, p
        elseif i == 2 then
                r, g, b = p, v, t
        elseif i == 3 then
                r, g, b = p, q, v
        elseif i == 4 then
                r, g, b = t, p, v
        else
                r, g, b = v, p, q
        end
        return rgb(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function round_to(v, step)
        if not step or step <= 0 then
                return v
        end
        return math.floor(v / step + 0.5) * step
end

local function make(class, props, parent)
        local inst = Instance.new(class)
        local real_parent = props.Parent or parent
        for k, v in pairs(props) do
                if k ~= "Parent" then
                        inst[k] = v
                end
        end
        if real_parent then
                inst.Parent = real_parent
        end
        return inst
end

local function corner(inst, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius)
        c.Parent = inst
        return c
end

local function stroke(inst, color, transparency, thickness)
        local s = Instance.new("UIStroke")
        s.Color = color
        s.Transparency = transparency
        s.Thickness = thickness or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = inst
        return s
end

local function gradient(inst, color, t_min, t_max, rotation)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(color)
        g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, t_min),
                NumberSequenceKeypoint.new(1, t_max),
        })
        g.Rotation = rotation or 0
        g.Parent = inst
        return g
end

local function tween(inst, time, props, style, direction)
        local info = TweenInfo.new(time or 0.12, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
        local tw = TweenService:Create(inst, info, props)
        tw:Play()
        return tw
end

local function safe_call(fn, ...)
        if type(fn) ~= "function" then
                return
        end
        local args = { ... }
        local ok, err = pcall(function()
                fn(unpack(args))
        end)
        if not ok then
                warn("[Airflow] callback error: " .. tostring(err))
        end
end

local function try(fn, ...)
        local ok, a, b = pcall(fn, ...)
        if ok then
                return a, b
        end
        return nil
end

local function has_canvas_group()
        local ok = pcall(function()
                local t = Instance.new("CanvasGroup")
                t:Destroy()
        end)
        return ok
end

local HAS_CG = has_canvas_group()

local DEFAULT_THEME = {
        Accent = rgb(255, 76, 25),
        Header = { Color = rgb(255, 255, 255), Transparency = 0.1 },
        HeaderLine = { Color = rgb(255, 255, 255), Transparency = 0.95 },
        Body = { Color = rgb(58, 58, 60), Transparency = 0.28 },
        Border = { Color = rgb(100, 100, 100), Transparency = 0.61 },
        Separator = { Color = rgb(255, 255, 255), Transparency = 0.95 },
        Element = { Color = rgb(217, 217, 217), Transparency = 0.92 },
        ElementHover = { Color = rgb(255, 255, 255), Transparency = 0.8 },
        ElementInner = { Color = rgb(0, 0, 0), Transparency = 0.69 },
        ElementInnerHover = { Color = rgb(38, 38, 38), Transparency = 0.57 },
        SubBar = { Color = rgb(217, 217, 217), Transparency = 0.92 },
        TabActive = { Color = rgb(255, 255, 255), Transparency = 0.96 },
        Popup = { Color = rgb(5, 5, 5), Transparency = 0.05 },
        Picker = { Color = rgb(16, 16, 16), Transparency = 0 },
        TextPrimary = { Color = rgb(255, 255, 255), Transparency = 0 },
        TextSecondary = { Color = rgb(255, 255, 255), Transparency = 0.5 },
        TextMuted = { Color = rgb(255, 255, 255), Transparency = 0.6 },
        Knob = { Color = rgb(75, 75, 75), Transparency = 0 },
        KnobInner = { Color = rgb(255, 255, 255), Transparency = 0 },
}

local function merge_theme(base, override)
        local out = {}
        for k, v in pairs(base) do
                out[k] = v
        end
        if type(override) == "table" then
                for k, v in pairs(override) do
                        if type(v) == "table" and type(out[k]) == "table" then
                                local sub = {}
                                for sk, sv in pairs(out[k]) do
                                        sub[sk] = sv
                                end
                                for sk, sv in pairs(v) do
                                        sub[sk] = sv
                                end
                                out[k] = sub
                        else
                                out[k] = v
                        end
                end
        end
        return out
end

local function theme_color(t, key)
        local v = t[key]
        if type(v) == "table" then
                return v.Color or rgb(255, 255, 255), v.Transparency or 0
        end
        return v or rgb(255, 255, 255), 0
end

local function protect_gui(gui)
        if type(gethui) == "function" then
                local ok, parent = pcall(gethui)
                if ok and parent then
                        gui.Parent = parent
                        return
                end
        end
        if type(syn) == "table" and type(syn.protect_gui) == "function" then
                local ok = pcall(syn.protect_gui, gui)
                if ok then
                        gui.Parent = game:GetService("CoreGui")
                        return
                end
        end
        local ok = pcall(function()
                gui.Parent = game:GetService("CoreGui")
        end)
        if ok then
                return
        end
        if LocalPlayer then
                gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
        end
end

local function get_clipboard()
        if type(setclipboard) == "function" then
                return setclipboard
        end
        if type(toclipboard) == "function" then
                return toclipboard
        end
        if type(syn) == "table" and type(syn.set_clipboard) == "function" then
                return syn.set_clipboard
        end
        return nil
end

local function read_clipboard()
        if type(getclipboard) == "function" then
                return getclipboard()
        end
        if type(syn) == "table" and type(syn.get_clipboard) == "function" then
                return syn.get_clipboard()
        end
        return ""
end

local function gui_inset()
        local ok, x, y = pcall(function()
                local inset = GuiService:GetGuiInset()
                return inset.X, inset.Y
        end)
        if ok then
                return x or 0, y or 0
        end
        return 0, 0
end

local function mouse_pos()
        local ok, v = pcall(function()
                return UserInputService:GetMouseLocation()
        end)
        if ok and v then
                local ix, iy = gui_inset()
                return v.X - ix, v.Y - iy
        end
        return 0, 0
end

local KEY_NAMES = {}
local function build_key_names()
        local names = {
                [Enum.KeyCode.A] = "A",
                [Enum.KeyCode.B] = "B",
                [Enum.KeyCode.C] = "C",
                [Enum.KeyCode.D] = "D",
                [Enum.KeyCode.E] = "E",
                [Enum.KeyCode.F] = "F",
                [Enum.KeyCode.G] = "G",
                [Enum.KeyCode.H] = "H",
                [Enum.KeyCode.I] = "I",
                [Enum.KeyCode.J] = "J",
                [Enum.KeyCode.K] = "K",
                [Enum.KeyCode.L] = "L",
                [Enum.KeyCode.M] = "M",
                [Enum.KeyCode.N] = "N",
                [Enum.KeyCode.O] = "O",
                [Enum.KeyCode.P] = "P",
                [Enum.KeyCode.Q] = "Q",
                [Enum.KeyCode.R] = "R",
                [Enum.KeyCode.S] = "S",
                [Enum.KeyCode.T] = "T",
                [Enum.KeyCode.U] = "U",
                [Enum.KeyCode.V] = "V",
                [Enum.KeyCode.W] = "W",
                [Enum.KeyCode.X] = "X",
                [Enum.KeyCode.Y] = "Y",
                [Enum.KeyCode.Z] = "Z",
                [Enum.KeyCode.Zero] = "0",
                [Enum.KeyCode.One] = "1",
                [Enum.KeyCode.Two] = "2",
                [Enum.KeyCode.Three] = "3",
                [Enum.KeyCode.Four] = "4",
                [Enum.KeyCode.Five] = "5",
                [Enum.KeyCode.Six] = "6",
                [Enum.KeyCode.Seven] = "7",
                [Enum.KeyCode.Eight] = "8",
                [Enum.KeyCode.Nine] = "9",
                [Enum.KeyCode.LeftShift] = "Lshift",
                [Enum.KeyCode.RightShift] = "Rshift",
                [Enum.KeyCode.LeftControl] = "Lcontrol",
                [Enum.KeyCode.RightControl] = "Rcontrol",
                [Enum.KeyCode.LeftAlt] = "Lmenu",
                [Enum.KeyCode.RightAlt] = "Rmenu",
                [Enum.KeyCode.Tab] = "Tab",
                [Enum.KeyCode.CapsLock] = "Caps",
                [Enum.KeyCode.Space] = "Spacebar",
                [Enum.KeyCode.Backspace] = "Back",
                [Enum.KeyCode.Enter] = "Enter",
                [Enum.KeyCode.Return] = "Enter",
                [Enum.KeyCode.Insert] = "Insert",
                [Enum.KeyCode.Delete] = "Delete",
                [Enum.KeyCode.Home] = "Home",
                [Enum.KeyCode.End] = "End",
                [Enum.KeyCode.PageUp] = "Pgup",
                [Enum.KeyCode.PageDown] = "Pgdwn",
                [Enum.KeyCode.Up] = "Up",
                [Enum.KeyCode.Down] = "Down",
                [Enum.KeyCode.Left] = "Left",
                [Enum.KeyCode.Right] = "Right",
                [Enum.KeyCode.F1] = "F1",
                [Enum.KeyCode.F2] = "F2",
                [Enum.KeyCode.F3] = "F3",
                [Enum.KeyCode.F4] = "F4",
                [Enum.KeyCode.F5] = "F5",
                [Enum.KeyCode.F6] = "F6",
                [Enum.KeyCode.F7] = "F7",
                [Enum.KeyCode.F8] = "F8",
                [Enum.KeyCode.F9] = "F9",
                [Enum.KeyCode.F10] = "F10",
                [Enum.KeyCode.F11] = "F11",
                [Enum.KeyCode.F12] = "F12",
                [Enum.KeyCode.Print] = "Prtsc",
                [Enum.KeyCode.ScrollLock] = "Scroll lock",
                [Enum.KeyCode.NumLock] = "Num lock",
                [Enum.KeyCode.Minus] = "-",
                [Enum.KeyCode.Equals] = "+",
                [Enum.KeyCode.LeftBracket] = "[{",
                [Enum.KeyCode.RightBracket] = "}]",
                [Enum.KeyCode.Semicolon] = ";",
                [Enum.KeyCode.Comma] = ",",
                [Enum.KeyCode.Period] = ".",
                [Enum.KeyCode.Slash] = "/?",
                [Enum.KeyCode.BackSlash] = "\\|",
                [Enum.KeyCode.Quote] = "'\"",
        }
        for k, v in pairs(names) do
                KEY_NAMES[k.Name] = v
        end
end
build_key_names()

local MOUSE_NAMES = {
        [Enum.UserInputType.MouseButton1] = "M1",
        [Enum.UserInputType.MouseButton2] = "M2",
        [Enum.UserInputType.MouseButton3] = "M3",
        [Enum.UserInputType.MouseButton4] = "M4",
        [Enum.UserInputType.MouseButton5] = "M5",
}

local function key_to_string(bind)
        if not bind.Key then
                return "None"
        end
        if bind.Key.UserInputType then
                local m = MOUSE_NAMES[bind.Key.UserInputType]
                if m then
                        return m
                end
        end
        if bind.Key.KeyCode then
                local n = KEY_NAMES[bind.Key.KeyCode.Name]
                if n then
                        return n
                end
                return bind.Key.KeyCode.Name
        end
        return "None"
end

local function input_is_mouse_button(input_type)
        return input_type == Enum.UserInputType.MouseButton1
                or input_type == Enum.UserInputType.MouseButton2
                or input_type == Enum.UserInputType.MouseButton3
                or input_type == Enum.UserInputType.MouseButton4
                or input_type == Enum.UserInputType.MouseButton5
end

local add_checkbox, add_slider, add_button, add_label, add_divider, add_space, add_dropdown, add_multidropdown, add_textbox, add_keybind, add_listbox, add_colorpicker
local ELEMENT_HEIGHTS = {
        checkbox = 32,
        slider = 56,
        combo = 48,
        multicombo = 48,
        button = 32,
        textbox = 48,
        keybind = 48,
        colorpicker = 48,
        listbox = 40,
        label = 18,
        divider = 10,
        space = 8,
}

local function build_logo_icon(parent, size, color)
        local holder = make("Frame", {
                Name = "LogoIcon",
                Size = UDim2.fromOffset(size, size),
                BackgroundTransparency = 1,
                Parent = parent,
        })
        local d = math.floor(size * 0.62)
        local bar1 = make("Frame", {
                Name = "B1",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(d, math.max(2, math.floor(size * 0.16))),
                BackgroundColor3 = color,
                Rotation = 45,
                BorderSizePixel = 0,
                Parent = holder,
        })
        local bar2 = make("Frame", {
                Name = "B2",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(d, math.max(2, math.floor(size * 0.16))),
                BackgroundColor3 = color,
                Rotation = -45,
                BorderSizePixel = 0,
                Parent = holder,
        })
        return holder
end

local function set_icon_display(win, holder, asset, size, color)
        for _, c in ipairs(holder:GetChildren()) do
                if c:IsA("ImageLabel") or c:IsA("Frame") then
                        c:Destroy()
                end
        end
        if asset ~= nil and asset ~= "" then
                local img = make("ImageLabel", {
                        Name = "Img",
                        Size = UDim2.fromOffset(size, size),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = asset,
                        ImageColor3 = color,
                        Parent = holder,
                })
        else
                build_logo_icon(holder, size, color)
        end
end

local function apply_accent(win)
        local accent = win.Theme.Accent
        for _, ref in ipairs(win._accent_refs) do
                if ref.inst and ref.inst.Parent then
                        if ref.kind == "bg" then
                                ref.inst.BackgroundColor3 = accent
                        elseif ref.kind == "text" then
                                ref.inst.TextColor3 = accent
                        elseif ref.kind == "stroke" then
                                ref.inst.Color = accent
                        elseif ref.kind == "gradient" then
                                ref.inst.Color = ColorSequence.new(accent)
                        elseif ref.kind == "icon" then
                                ref.inst.ImageColor3 = accent
                        end
                end
        end
        for _, fn in ipairs(win._accent_hooks) do
                safe_call(fn, accent)
        end
end

local function apply_theme(win)
        local t = win.Theme
        local function set_prop(inst, prop, value)
                if inst and inst.Parent then
                        inst[prop] = value
                end
        end
        if win._chrome.Header then
                set_prop(win._chrome.Header, "BackgroundColor3", t.Header.Color)
                set_prop(win._chrome.Header, "BackgroundTransparency", t.Header.Transparency)
        end
        if win._chrome.Body then
                set_prop(win._chrome.Body, "BackgroundColor3", t.Body.Color)
                set_prop(win._chrome.Body, "BackgroundTransparency", t.Body.Transparency)
        end
        if win._chrome.HeaderLine then
                set_prop(win._chrome.HeaderLine, "BackgroundColor3", t.HeaderLine.Color)
                set_prop(win._chrome.HeaderLine, "BackgroundTransparency", t.HeaderLine.Transparency)
        end
        if win._chrome.SidebarLine then
                set_prop(win._chrome.SidebarLine, "BackgroundColor3", t.Separator.Color)
                set_prop(win._chrome.SidebarLine, "BackgroundTransparency", t.Separator.Transparency)
        end
        if win._chrome.Border then
                set_prop(win._chrome.Border, "Color", t.Border.Color)
                set_prop(win._chrome.Border, "Transparency", t.Border.Transparency)
        end
        if win._chrome.TitleLabel then
                set_prop(win._chrome.TitleLabel, "TextColor3", t.TextPrimary.Color)
        end
        if win._chrome.SubBar then
                set_prop(win._chrome.SubBar, "BackgroundColor3", t.SubBar.Color)
                set_prop(win._chrome.SubBar, "BackgroundTransparency", t.SubBar.Transparency)
        end
        for _, ref in ipairs(win._element_bgs or {}) do
                local c, tr = theme_color(t, ref.use_inner and "ElementInner" or "Element")
                set_prop(ref.frame, "BackgroundColor3", c)
                set_prop(ref.frame, "BackgroundTransparency", tr)
        end
        if win._chrome.KeybindsList then
                win:RefreshKeybindList()
        end
        for _, fn in ipairs(win._theme_hooks) do
                safe_call(fn, t)
        end
        apply_accent(win)
end

local function track_accent(win, inst, kind)
        table.insert(win._accent_refs, { inst = inst, kind = kind or "bg" })
        if inst then
                if kind == "bg" or not kind then
                        inst.BackgroundColor3 = win.Theme.Accent
                elseif kind == "text" then
                        inst.TextColor3 = win.Theme.Accent
                elseif kind == "stroke" then
                        inst.Color = win.Theme.Accent
                elseif kind == "gradient" then
                        inst.Color = ColorSequence.new(win.Theme.Accent)
                elseif kind == "icon" then
                        inst.ImageColor3 = win.Theme.Accent
                end
        end
        return inst
end

local function popup_reposition(win)
        local p = win._popup
        if not p or not p.anchor then
                return
        end
        local ok = pcall(function()
                local ap = p.anchor.AbsolutePosition
                local rp = win.Root.AbsolutePosition
                local x = ap.X - rp.X + p.offset_x
                local y = ap.Y - rp.Y + p.offset_y
                x = clamp(x, 4, 716 - p.frame.AbsoluteSize.X)
                y = clamp(y, 4, 516 - p.frame.AbsoluteSize.Y)
                p.frame.Position = UDim2.fromOffset(x, y)
        end)
end

local function close_popup(win)
        local p = win._popup
        if not p then
                return
        end
        win._popup = nil
        if p.catcher then
                p.catcher.Visible = false
        end
        if p.on_close then
                safe_call(p.on_close)
        end
        if p.frame then
                if p.kill then
                        p.frame:Destroy()
                else
                        p.frame.Visible = false
                end
        end
        if p.preview_update then
                safe_call(p.preview_update, false)
        end
end

local function open_popup(win, frame, anchor, offset_x, offset_y, on_close, opts)
        opts = opts or {}
        close_popup(win)
        local catcher = win._catcher
        catcher.Visible = true
        catcher.ZIndex = 900
        frame.ZIndex = 950
        frame.Visible = true
        frame.Parent = win.PopupLayer
        win._popup = {
                frame = frame,
                anchor = anchor,
                offset_x = offset_x,
                offset_y = offset_y,
                on_close = on_close,
                catcher = catcher,
                kill = opts.kill or false,
                preview_update = opts.preview_update,
        }
        popup_reposition(win)
end

local function make_element_base(win, group, kind, height)
        local holder = make("Frame", {
                Name = kind,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, height),
                LayoutOrder = group:_next_order(),
                Parent = group._content_frame,
        })
        local el = {}
        el.Holder = holder
        el.Window = win
        el.Group = group
        el.Kind = kind
        el.Visible = true
        function el:SetVisible(state)
                state = state and true or false
                el.Visible = state
                holder.Visible = state
        end
        function el:GetVisible()
                return el.Visible
        end
        return el, holder
end

local function hover_style(win, frame, use_inner)
        local base_c, base_t = theme_color(win.Theme, "Element")
        if use_inner then
                base_c, base_t = theme_color(win.Theme, "ElementInner")
        end
        frame.BackgroundColor3 = base_c
        frame.BackgroundTransparency = base_t
        table.insert(win._element_bgs, { frame = frame, use_inner = use_inner })
        frame.MouseEnter:Connect(function()
                local c, t = theme_color(win.Theme, use_inner and "ElementInnerHover" or "ElementHover")
                tween(frame, 0.08, { BackgroundColor3 = c, BackgroundTransparency = t })
        end)
        frame.MouseLeave:Connect(function()
                local c, t = theme_color(win.Theme, use_inner and "ElementInner" or "Element")
                tween(frame, 0.1, { BackgroundColor3 = c, BackgroundTransparency = t })
        end)
        return frame
end

local function build_window(opts)
        local win = {}
        win.Options = opts
        win.Theme = merge_theme(DEFAULT_THEME, opts.Theme)
        win.Font = opts.Font or Enum.Font.GothamMedium
        win.Name = opts.Name or "airflow"
        win.Title = opts.Title or win.Name
        win.Icon = opts.Icon
        win.Open = false
        win.Destroyed = false
        win.Tabs = {}
        win.CurrentTab = nil
        win.CurrentSubTab = nil
        win._accent_refs = {}
        win._accent_hooks = {}
        win._theme_hooks = {}
        win._element_bgs = {}
        win._conns = {}
        win._popup = nil
        win._flags = {}
        win._binds = {}
        win._text_focus = 0
        win._scale = opts.Scale or 1
        win._draggable = opts.Draggable ~= false
        win._blur = nil

        local scale = opts.Scale or 1
        local scr = make("ScreenGui", {
                Name = opts.GuiName or ("Airflow_" .. tostring(math.floor(math.random() * 100000))),
                ResetOnSpawn = false,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                DisplayOrder = 9999,
                IgnoreGuiInset = false,
                Enabled = true,
        })

        local main
        if HAS_CG then
                main = make("CanvasGroup", {
                        Name = "Main",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new(0.5, opts.OffsetX or 0, 0.5, opts.OffsetY or 0),
                        Size = UDim2.fromOffset(720, 520),
                        BackgroundTransparency = 1,
                        GroupTransparency = 1,
                        BorderSizePixel = 0,
                        Parent = scr,
                })
        else
                main = make("Frame", {
                        Name = "Main",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new(0.5, opts.OffsetX or 0, 0.5, opts.OffsetY or 0),
                        Size = UDim2.fromOffset(720, 520),
                        BackgroundTransparency = 1,
                        Visible = false,
                        BorderSizePixel = 0,
                        Parent = scr,
                })
        end
        win.ScreenGui = scr
        win.Main = main

        local scale_obj = make("UIScale", { Scale = scale, Parent = main })

        local root = make("Frame", {
                Name = "Root",
                Size = UDim2.fromOffset(720, 520),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = main,
        })
        win.Root = root

        local window_frame = make("Frame", {
                Name = "Window",
                Size = UDim2.fromOffset(720, 520),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = root,
        })
        win.WindowFrame = window_frame
        local border = stroke(window_frame, win.Theme.Border.Color, win.Theme.Border.Transparency, 1)
        win._chrome = {}
        win._chrome.Border = border
        corner(window_frame, 6)

        local header = make("Frame", {
                Name = "Header",
                Size = UDim2.fromOffset(720, 47),
                BackgroundColor3 = win.Theme.Header.Color,
                BackgroundTransparency = win.Theme.Header.Transparency,
                BorderSizePixel = 0,
                Parent = window_frame,
        })
        win._chrome.Header = header
        corner(header, 6)

        local header_line = make("Frame", {
                Name = "HeaderLine",
                Position = UDim2.fromOffset(0, 46),
                Size = UDim2.fromOffset(720, 1),
                BackgroundColor3 = win.Theme.HeaderLine.Color,
                BackgroundTransparency = win.Theme.HeaderLine.Transparency,
                BorderSizePixel = 0,
                Parent = window_frame,
        })
        win._chrome.HeaderLine = header_line

        local body = make("Frame", {
                Name = "Body",
                Position = UDim2.fromOffset(0, 47),
                Size = UDim2.fromOffset(720, 473),
                BackgroundColor3 = win.Theme.Body.Color,
                BackgroundTransparency = win.Theme.Body.Transparency,
                BorderSizePixel = 0,
                Parent = window_frame,
        })
        win._chrome.Body = body
        corner(body, 6)

        local title_holder = make("Frame", {
                Name = "TitleHolder",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 21, 0.5, 0),
                Size = UDim2.fromOffset(0, 20),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Parent = header,
        })
        local title_layout = make("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 16),
                Parent = title_holder,
        })

        local icon_holder = make("Frame", {
                Name = "IconHolder",
                Size = UDim2.fromOffset(14, 14),
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Parent = title_holder,
        })
        win._icon_holder = icon_holder

        local title_label = make("TextLabel", {
                Name = "Title",
                Size = UDim2.fromOffset(0, 20),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 18,
                Text = win.Title,
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
                Parent = title_holder,
        })
        win._chrome.TitleLabel = title_label

        set_icon_display(win, icon_holder, win.Icon, 14, win.Theme.Accent)

        local sidebar_line = make("Frame", {
                Name = "SidebarLine",
                Position = UDim2.fromOffset(160, 47),
                Size = UDim2.fromOffset(1, 473),
                BackgroundColor3 = win.Theme.Separator.Color,
                BackgroundTransparency = win.Theme.Separator.Transparency,
                BorderSizePixel = 0,
                Parent = window_frame,
        })
        win._chrome.SidebarLine = sidebar_line

        local tab_holder = make("Frame", {
                Name = "TabHolder",
                Position = UDim2.fromOffset(0, 47),
                Size = UDim2.fromOffset(160, 473),
                BackgroundTransparency = 1,
                Parent = window_frame,
        })
        win.TabHolder = tab_holder

        local sub_bar = make("Frame", {
                Name = "SubBar",
                Position = UDim2.fromOffset(178, 62),
                Size = UDim2.fromOffset(528, 58),
                BackgroundColor3 = win.Theme.SubBar.Color,
                BackgroundTransparency = win.Theme.SubBar.Transparency,
                BorderSizePixel = 0,
                Parent = window_frame,
        })
        win._chrome.SubBar = sub_bar
        corner(sub_bar, 4)

        local sub_holder = make("Frame", {
                Name = "SubHolder",
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(528, 58),
                Parent = sub_bar,
        })
        win.SubHolder = sub_holder

        local popup_layer = make("Frame", {
                Name = "PopupLayer",
                Size = UDim2.fromOffset(720, 520),
                BackgroundTransparency = 1,
                ClipsDescendants = false,
                Parent = root,
        })
        win.PopupLayer = popup_layer

        local catcher = make("TextButton", {
                Name = "PopupCatcher",
                Size = UDim2.fromOffset(720, 520),
                BackgroundTransparency = 1,
                Text = "",
                Visible = false,
                AutoButtonColor = false,
                Parent = popup_layer,
        })
        win._catcher = catcher
        table.insert(win._conns, catcher.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
                        close_popup(win)
                end
        end))

        if opts.Blur ~= false then
                local ok, blur = pcall(function()
                        local b = Instance.new("BlurEffect")
                        b.Name = "AirflowBlur"
                        b.Size = 0
                        b.Parent = Lighting
                        return b
                end)
                if ok then
                        win._blur = blur
                end
        end

        win._chrome.KeybindsList = nil
        win._chrome.Watermark = nil

        function win:SetScale(s)
                win._scale = s or 1
                scale_obj.Scale = win._scale
        end

        function win:GetScale()
                return win._scale
        end

        function win:SetPosition(x, y)
                main.Position = UDim2.new(0.5, x or 0, 0.5, y or 0)
        end

        function win:GetPosition()
                return main.Position.Offset.X, main.Position.Offset.Y
        end

        return win, scr, main, scale_obj
end

local function setup_drag(win)
        local dragging = false
        local drag_start = nil
        local frame_start = nil
        local header = win._chrome.Header

        table.insert(win._conns, header.InputBegan:Connect(function(input)
                if not win._draggable then
                        return
                end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        drag_start = input.Position
                        frame_start = win.Main.Position
                        close_popup(win)
                end
        end))

        table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        local dx = input.Position.X - drag_start.X
                        local dy = input.Position.Y - drag_start.Y
                        win.Main.Position = UDim2.new(frame_start.X.Scale, frame_start.X.Offset + dx, frame_start.Y.Scale, frame_start.Y.Offset + dy)
                end
        end))

        table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                end
        end))
end
local function set_tab_visible(win, tab, state)
        if not tab then
                return
        end
        tab.Root.Visible = state
end

local function select_tab(win, index)
        local tab = win.Tabs[index]
        if not tab then
                return
        end
        close_popup(win)
        if win.CurrentTab then
                local prev = win.Tabs[win.CurrentTab]
                if prev then
                        set_tab_visible(win, prev, false)
                end
        end
        win.CurrentTab = index
        set_tab_visible(win, tab, true)
        tween(tab.TabBg, 0.12, { BackgroundTransparency = win.Theme.TabActive.Transparency })
        tween(tab.Accent, 0.12, { BackgroundTransparency = 0 })
        tween(tab.Text, 0.12, { TextTransparency = 0 })
        if HAS_CG and tab.Root:IsA("CanvasGroup") then
                tab.Root.GroupTransparency = 1
                tween(tab.Root, 0.14, { GroupTransparency = 0 })
        end
        local subs = tab.SubTabs
        if #subs > 0 then
                local target = 1
                if tab.LastSub and tab.LastSub <= #subs then
                        target = tab.LastSub
                end
                select_sub_tab(win, tab, target)
        else
                win.CurrentSubTab = nil
                win._chrome.SubBar.Visible = false
        end
end

local function build_tab_button(win, tab, index)
        local y = 63 + 40 * (index - 1)
        local btn = make("TextButton", {
                Name = "Tab_" .. tab.Name,
                Position = UDim2.fromOffset(8, y),
                Size = UDim2.fromOffset(144, 32),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = win.TabHolder,
        })
        tab.Button = btn
        tab.TabBg = make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(142, 32),
                BackgroundColor3 = win.Theme.TabActive.Color,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = btn,
        })
        corner(tab.TabBg, 4)
        tab.Accent = track_accent(win, make("Frame", {
                Name = "Accent",
                Position = UDim2.fromOffset(142, 0),
                Size = UDim2.fromOffset(2, 32),
                BackgroundColor3 = win.Theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = btn,
        }), "bg")
        local icon_holder = make("Frame", {
                Name = "IconHolder",
                Position = UDim2.fromOffset(10, 9),
                Size = UDim2.fromOffset(15, 15),
                BackgroundTransparency = 1,
                Parent = btn,
        })
        tab.IconHolder = icon_holder
        tab.Text = make("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(32, 8),
                Size = UDim2.fromOffset(100, 16),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tab.Name,
                TextColor3 = win.Theme.TextPrimary.Color,
                TextTransparency = transp(150),
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = btn,
        })
        table.insert(win._theme_hooks, function()
                if win.CurrentTab ~= index then
                        tab.Text.TextColor3 = win.Theme.TextPrimary.Color
                        tab.Text.TextTransparency = transp(150)
                end
        end)
        btn.MouseEnter:Connect(function()
                if win.CurrentTab ~= index then
                        tween(tab.Text, 0.1, { TextTransparency = transp(60) })
                end
        end)
        btn.MouseLeave:Connect(function()
                if win.CurrentTab ~= index then
                        tween(tab.Text, 0.1, { TextTransparency = transp(150) })
                end
        end)
        btn.Activated:Connect(function()
                select_tab(win, index)
        end)
end

local function build_sub_tab_button(win, tab, sub, index, row)
        local btn = make("TextButton", {
                Name = "Sub_" .. sub.Name,
                Position = UDim2.fromOffset(19 + 80 * (index - 1), 14),
                Size = UDim2.fromOffset(70, 32),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = row,
        })
        sub.Button = btn
        sub.Bg = make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(70, 32),
                BackgroundColor3 = win.Theme.SubBar.Color,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = btn,
        })
        corner(sub.Bg, 4)
        sub.Accent = track_accent(win, make("Frame", {
                Name = "Accent",
                Position = UDim2.fromOffset(15, 30),
                Size = UDim2.fromOffset(40, 2),
                BackgroundColor3 = win.Theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = btn,
        }), "bg")
        sub.Text = make("TextLabel", {
                Name = "Label",
                Size = UDim2.fromOffset(70, 32),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = sub.Name,
                TextColor3 = win.Theme.TextPrimary.Color,
                TextTransparency = transp(150),
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                Parent = btn,
        })
        btn.MouseEnter:Connect(function()
                if tab.CurrentSub ~= index then
                        tween(sub.Text, 0.1, { TextTransparency = transp(60) })
                end
        end)
        btn.MouseLeave:Connect(function()
                if tab.CurrentSub ~= index then
                        tween(sub.Text, 0.1, { TextTransparency = transp(150) })
                end
        end)
        btn.Activated:Connect(function()
                select_sub_tab(win, tab, index)
        end)
end

function select_sub_tab(win, tab, index)
        local sub = tab.SubTabs[index]
        if not sub then
                return
        end
        close_popup(win)
        if tab.CurrentSub then
                local prev = tab.SubTabs[tab.CurrentSub]
                if prev then
                        prev.Root.Visible = false
                        tween(prev.Bg, 0.12, { BackgroundTransparency = 1 })
                        tween(prev.Accent, 0.12, { BackgroundTransparency = 1 })
                        tween(prev.Text, 0.12, { TextTransparency = transp(150) })
                end
        end
        tab.CurrentSub = index
        tab.LastSub = index
        win.CurrentSubTab = sub
        sub.Root.Visible = true
        tween(sub.Bg, 0.12, { BackgroundTransparency = win.Theme.SubBar.Transparency })
        tween(sub.Accent, 0.12, { BackgroundTransparency = 0 })
        tween(sub.Text, 0.12, { TextTransparency = 0 })
        win._chrome.SubBar.Visible = true
        if HAS_CG and sub.Root:IsA("CanvasGroup") then
                sub.Root.GroupTransparency = 1
                tween(sub.Root, 0.12, { GroupTransparency = 0 })
        end
        if sub.Scroll then
                sub.Scroll.CanvasPosition = Vector2.new(0, 0)
        end
end

local function fade_window(win, state)
        local main = win.Main
        if state then
                main.Visible = true
                if HAS_CG then
                        main.GroupTransparency = 1
                        tween(main, 0.16, { GroupTransparency = 0 })
                end
                if win._blur then
                        tween(win._blur, 0.16, { Size = 24 })
                end
                win.Open = true
        else
                if HAS_CG then
                        local tw = tween(main, 0.16, { GroupTransparency = 1 })
                        tw.Completed:Connect(function()
                                if not win.Open then
                                        main.Visible = false
                                end
                        end)
                else
                        main.Visible = false
                end
                if win._blur then
                        tween(win._blur, 0.16, { Size = 0 })
                end
                win.Open = false
                close_popup(win)
        end
end

local function set_blur_enabled(win, enabled)
        if enabled then
                if not win._blur then
                        local ok, blur = pcall(function()
                                local b = Instance.new("BlurEffect")
                                b.Name = "AirflowBlur"
                                b.Size = win.Open and 24 or 0
                                b.Parent = Lighting
                                return b
                        end)
                        if ok then
                                win._blur = blur
                        end
                end
        elseif win._blur then
                win._blur:Destroy()
                win._blur = nil
        end
end

local function groupbox_next_order(group)
        group._order = group._order + 1
        return group._order
end

local function create_groupbox(win, column, title)
        local group = {}
        group._column = column
        group._order = 0
        group._win = win

        local frame = make("Frame", {
                Name = "Group_" .. title,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = column._order,
                Parent = column.Frame,
        })
        column._order = column._order + 1
        group._content_frame = frame

        local label = make("TextLabel", {
                Name = "Title",
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = title,
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = frame,
        })
        group.Title = label

        local list = make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = frame,
        })

        local tail = make("Frame", {
                Name = "Tail",
                Size = UDim2.new(1, 0, 0, 5),
                BackgroundTransparency = 1,
                LayoutOrder = 999999,
                Parent = frame,
        })

        function group:_next_order()
                return groupbox_next_order(group)
        end

        function group:SetTitle(text)
                label.Text = tostring(text)
        end

        function group:GetTitle()
                return label.Text
        end

        function group:_register_flag(flag, el)
                if flag then
                        win._flag_els[flag] = el
                end
        end

        function group:AddCheckbox(name, opts)
                return add_checkbox(win, group, name, opts)
        end

        function group:AddToggle(name, opts)
                return add_checkbox(win, group, name, opts)
        end

        function group:AddSlider(name, opts)
                return add_slider(win, group, name, opts)
        end

        function group:AddButton(name, opts)
                return add_button(win, group, name, opts)
        end

        function group:AddLabel(text, opts)
                return add_label(win, group, text, opts)
        end

        function group:AddText(text, opts)
                return add_label(win, group, text, opts)
        end

        function group:AddDivider()
                return add_divider(win, group)
        end

        function group:AddSpace(h)
                return add_space(win, group, h)
        end

        function group:AddDropdown(name, opts)
                return add_dropdown(win, group, name, opts)
        end

        function group:AddCombo(name, opts)
                return add_dropdown(win, group, name, opts)
        end

        function group:AddMultiDropdown(name, opts)
                return add_multidropdown(win, group, name, opts)
        end

        function group:AddMultiCombo(name, opts)
                return add_multidropdown(win, group, name, opts)
        end

        function group:AddTextbox(name, opts)
                return add_textbox(win, group, name, opts)
        end

        function group:AddInput(name, opts)
                return add_textbox(win, group, name, opts)
        end

        function group:AddKeybind(name, opts)
                return add_keybind(win, group, name, opts)
        end

        function group:AddBind(name, opts)
                return add_keybind(win, group, name, opts)
        end

        function group:AddColorPicker(name, opts)
                return add_colorpicker(win, group, name, opts)
        end

        function group:AddColor(name, opts)
                return add_colorpicker(win, group, name, opts)
        end

        function group:AddListbox(name, opts)
                return add_listbox(win, group, name, opts)
        end

        function group:AddList(name, opts)
                return add_listbox(win, group, name, opts)
        end

        return group
end

local function build_columns(win, parent)
        local holder = make("Frame", {
                Name = "Columns",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = parent,
        })
        local left = make("Frame", {
                Name = "Left",
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromOffset(256, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = holder,
        })
        local right = make("Frame", {
                Name = "Right",
                Position = UDim2.fromOffset(270, 0),
                Size = UDim2.fromOffset(256, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = holder,
        })
        local function column_layout(f)
                make("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 4),
                        Parent = f,
                })
        end
        column_layout(left)
        column_layout(right)
        local left_col = { Frame = left, _order = 0 }
        local right_col = { Frame = right, _order = 0 }
        return left_col, right_col
end

function add_checkbox(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "checkbox", ELEMENT_HEIGHTS.checkbox)
        local bg = hover_style(win, make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(256, 32),
                BorderSizePixel = 0,
                Parent = holder,
        }), false)
        corner(bg, 4)
        make("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(12, 7),
                Size = UDim2.fromOffset(190, 18),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(name),
                TextColor3 = win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = bg,
        })
        local pill = make("Frame", {
                Name = "Pill",
                Position = UDim2.fromOffset(220, 9),
                Size = UDim2.fromOffset(28, 14),
                BackgroundColor3 = win.Theme.ElementInner.Color,
                BackgroundTransparency = win.Theme.ElementInner.Transparency,
                BorderSizePixel = 0,
                Parent = bg,
        })
        corner(pill, 8)
        local knob_holder = make("Frame", {
                Name = "KnobHolder",
                Position = UDim2.fromOffset(3, 3),
                Size = UDim2.fromOffset(22, 8),
                BackgroundTransparency = 1,
                Parent = pill,
        })
        local knob = track_accent(win, make("Frame", {
                Name = "Knob",
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = win.Theme.Accent,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Parent = knob_holder,
        }), "bg")
        corner(knob, 4)

        local state = opts.Default == true
        local click = make("TextButton", {
                Name = "Hit",
                Size = UDim2.fromOffset(256, 32),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = bg,
        })

        local function render(instant)
                local target_pos = state and 14 or 0
                local target_tr = state and 0 or 1
                if instant then
                        knob.Position = UDim2.fromOffset(target_pos, 0)
                        knob.BackgroundTransparency = target_tr
                else
                        tween(knob, 0.14, { Position = UDim2.fromOffset(target_pos, 0), BackgroundTransparency = target_tr })
                end
        end
        render(true)

        local function set(v, silent)
                if v == state then
                        return
                end
                state = v and true or false
                render(false)
                el.Value = state
                if not silent then
                        safe_call(opts.Callback, state)
                end
                if opts.Flag then
                        win._flags[opts.Flag] = state
                end
        end

        click.Activated:Connect(function()
                set(not state)
        end)

        el.Value = state
        if opts.Flag then
                win._flags[opts.Flag] = state
        end
        function el:Set(v)
                set(v == true, true)
                render(true)
        end
        function el:Get()
                return state
        end
        function el:SetLabel(text)
                bg.Label.Text = tostring(text)
        end
        group:_register_flag(opts.Flag, el)
        return el
end

function add_slider(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "slider", ELEMENT_HEIGHTS.slider)
        local min_v = opts.Min or 0
        local max_v = opts.Max or 100
        if min_v > max_v then
                local t = min_v
                min_v = max_v
                max_v = t
        end
        local step = opts.Step or 1
        local default = clamp(opts.Default or min_v, min_v, max_v)
        local suffix = opts.Suffix or ""
        local prefix = opts.Prefix or ""

        local bg = hover_style(win, make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(256, 56),
                BorderSizePixel = 0,
                Parent = holder,
        }), false)
        corner(bg, 4)
        make("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(12, 9),
                Size = UDim2.fromOffset(180, 18),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(name),
                TextColor3 = win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = bg,
        })
        local value_label = make("TextLabel", {
                Name = "Value",
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -23, 0, 9),
                Size = UDim2.fromOffset(120, 18),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = "",
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Right,
                Parent = bg,
        })

        local bar = make("Frame", {
                Name = "Bar",
                Position = UDim2.fromOffset(12, 37),
                Size = UDim2.fromOffset(232, 6),
                BackgroundColor3 = win.Theme.ElementInner.Color,
                BackgroundTransparency = win.Theme.ElementInner.Transparency,
                BorderSizePixel = 0,
                Parent = bg,
        })
        corner(bar, 3)
        local fill = make("Frame", {
                Name = "Fill",
                Size = UDim2.new(0, 0, 1, 2),
                Position = UDim2.fromOffset(0, -1),
                BackgroundColor3 = win.Theme.Accent,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Parent = bar,
        })
        corner(fill, 4)
        track_accent(win, gradient(fill, win.Theme.Accent, 0.5, 0, 0), "gradient")

        local knob_outer = make("Frame", {
                Name = "KnobOuter",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = win.Theme.Knob.Color,
                BackgroundTransparency = win.Theme.Knob.Transparency,
                BorderSizePixel = 0,
                Parent = bar,
        })
        corner(knob_outer, 8)
        local knob_inner = make("Frame", {
                Name = "KnobInner",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.fromOffset(10, 10),
                BackgroundColor3 = win.Theme.KnobInner.Color,
                BackgroundTransparency = win.Theme.KnobInner.Transparency,
                BorderSizePixel = 0,
                Parent = knob_outer,
        })
        corner(knob_inner, 5)

        local hit = make("TextButton", {
                Name = "Hit",
                Position = UDim2.fromOffset(0, 25),
                Size = UDim2.fromOffset(256, 31),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = bg,
        })

        local value = default
        el.Value = value

        local function fmt(v)
                if type(opts.Format) == "function" then
                        return tostring(opts.Format(v))
                end
                local s = nil
                if step >= 1 then
                        s = tostring(math.floor(v + 0.5))
                else
                        s = string.format("%.2f", v)
                end
                return prefix .. s .. suffix
        end

        local function render(instant)
                local alpha = (value - min_v) / (max_v - min_v)
                local w = clamp(alpha, 0, 1) * 232
                if instant then
                        fill.Size = UDim2.new(0, w, 1, 2)
                        knob_outer.Position = UDim2.new(0, w, 0.5, 0)
                else
                        tween(fill, 0.06, { Size = UDim2.new(0, w, 1, 2) }, Enum.EasingStyle.Linear)
                        tween(knob_outer, 0.06, { Position = UDim2.new(0, w, 0.5, 0) }, Enum.EasingStyle.Linear)
                end
                value_label.Text = fmt(value)
        end

        local function set(v, silent, instant)
                v = clamp(v, min_v, max_v)
                v = round_to(v, step)
                if v ~= value or silent then
                        value = v
                        el.Value = v
                        render(instant)
                        if opts.Flag then
                                win._flags[opts.Flag] = v
                        end
                        if not silent then
                                safe_call(opts.Callback, v)
                        end
                end
        end

        local dragging = false
        local function apply_from_mouse()
                local ok = pcall(function()
                        local mx, _ = mouse_pos()
                        local ap = bar.AbsolutePosition
                        local as = bar.AbsoluteSize
                        local t = clamp((mx - ap.X) / as.X, 0, 1)
                        set(min_v + t * (max_v - min_v), false, true)
                end)
        end

        table.insert(win._conns, hit.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        apply_from_mouse()
                end
        end))
        table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        apply_from_mouse()
                end
        end))
        table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                end
        end))

        set(default, true, true)

        function el:Set(v)
                set(v, true, false)
        end
        function el:Get()
                return value
        end
        function el:SetMin(v)
                min_v = v
                set(value, true, true)
        end
        function el:SetMax(v)
                max_v = v
                set(value, true, true)
        end
        function el:SetRange(a, b)
                min_v, max_v = a, b
                set(value, true, true)
        end
        function el:SetLabel(text)
                bg.Label.Text = tostring(text)
        end
        function el:SetSuffix(s)
                suffix = tostring(s)
                render(true)
        end
        group:_register_flag(opts.Flag, el)
        return el
end

function add_button(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "button", ELEMENT_HEIGHTS.button)
        local bg = hover_style(win, make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(256, 32),
                BorderSizePixel = 0,
                Parent = holder,
        }), false)
        corner(bg, 4)
        local label = make("TextLabel", {
                Name = "Label",
                Size = UDim2.fromOffset(256, 32),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(name),
                TextColor3 = win.Theme.TextPrimary.Color,
                TextTransparency = opts.Secondary and transp(128) or 0,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = bg,
        })
        local click = make("TextButton", {
                Name = "Hit",
                Size = UDim2.fromOffset(256, 32),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                Parent = bg,
        })
        local last_click = 0
        click.Activated:Connect(function()
                local now = os.clock()
                if opts.Confirm then
                        if now - last_click < 1.5 then
                                last_click = 0
                                label.Text = tostring(name)
                                label.TextColor3 = win.Theme.TextPrimary.Color
                                safe_call(opts.Callback)
                        else
                                last_click = now
                                label.Text = "sure?"
                                label.TextColor3 = win.Theme.Accent
                                task.delay(1.5, function()
                                        if last_click ~= 0 and now == last_click then
                                                label.Text = tostring(name)
                                                label.TextColor3 = win.Theme.TextPrimary.Color
                                                last_click = 0
                                        end
                                end)
                        end
                else
                        safe_call(opts.Callback)
                end
        end)
        function el:SetLabel(text)
                label.Text = tostring(text)
        end
        function el:SetText(text)
                label.Text = tostring(text)
        end
        return el
end

function add_label(win, group, text, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "label", ELEMENT_HEIGHTS.label)
        local label = make("TextLabel", {
                Name = "Text",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = opts.Size or 14,
                Text = tostring(text),
                TextColor3 = opts.Color or win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = opts.Wrapped == true,
                Parent = holder,
        })
        if opts.Wrapped then
                holder.Size = UDim2.new(1, 0, 0, opts.Height or 30)
        end
        function el:Set(text)
                label.Text = tostring(text)
        end
        function el:Get()
                return label.Text
        end
        function el:SetColor(c)
                label.TextColor3 = c
        end
        return el
end

function add_divider(win, group)
        local el, holder = make_element_base(win, group, "divider", ELEMENT_HEIGHTS.divider)
        local line = make("Frame", {
                Name = "Line",
                Position = UDim2.fromOffset(0, 4),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = win.Theme.Separator.Color,
                BackgroundTransparency = win.Theme.Separator.Transparency,
                BorderSizePixel = 0,
                Parent = holder,
        })
        return el
end

function add_space(win, group, h)
        local el, holder = make_element_base(win, group, "space", h or ELEMENT_HEIGHTS.space)
        return el
end
local function combo_preview_slide(win, el, is_open)
	local label = el._preview
	if not label then
		return
	end
	if is_open then
		label.TextXAlignment = Enum.TextXAlignment.Left
		tween(label, 0.12, { Position = UDim2.fromOffset(133, 17) })
	else
		tween(label, 0.12, { Position = UDim2.fromOffset(133, 17) })
	end
end

local function truncate(text, max_len)
	text = tostring(text)
	if #text > max_len then
		return string.sub(text, 1, max_len) .. "..."
	end
	return text
end

function add_dropdown(win, group, name, opts)
	opts = opts or {}
	local el, holder = make_element_base(win, group, "combo", ELEMENT_HEIGHTS.combo)
	local options = {}
	for i, v in ipairs(opts.Options or {}) do
		options[i] = tostring(v)
	end
	local selected = nil
	local selected_index = 0
	if type(opts.Default) == "number" then
		selected_index = opts.Default
		selected = options[opts.Default]
	elseif type(opts.Default) == "string" then
		for i, v in ipairs(options) do
			if v == opts.Default then
				selected_index = i
				selected = v
			end
		end
	end
	if not selected and #options > 0 then
		selected_index = 1
		selected = options[1]
	end

	local bg = hover_style(win, make("Frame", {
		Name = "Bg",
		Size = UDim2.fromOffset(256, 48),
		BorderSizePixel = 0,
		Parent = holder,
	}), false)
	corner(bg, 4)
	make("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(110, 18),
		BackgroundTransparency = 1,
		Font = win.Font,
		TextSize = 14,
		Text = tostring(name),
		TextColor3 = win.Theme.TextSecondary.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bg,
	})

	local line1 = make("Frame", {
		Name = "ArrowL",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(234, 24),
		Size = UDim2.fromOffset(6, 1.5),
		BackgroundColor3 = win.Theme.TextPrimary.Color,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Rotation = 45,
		Parent = bg,
	})
	local line2 = make("Frame", {
		Name = "ArrowR",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(239, 23.5),
		Size = UDim2.fromOffset(6, 1.5),
		BackgroundColor3 = win.Theme.TextPrimary.Color,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Rotation = -45,
		Parent = bg,
	})

	local preview = make("TextLabel", {
		Name = "Preview",
		Position = UDim2.fromOffset(133, 17),
		Size = UDim2.fromOffset(87, 16),
		BackgroundTransparency = 1,
		Font = win.Font,
		TextSize = 14,
		Text = selected and truncate(selected, 15) or "Select",
		TextColor3 = win.Theme.TextPrimary.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Parent = bg,
	})
	el._preview = preview

	local click = make("TextButton", {
		Name = "Hit",
		Size = UDim2.fromOffset(256, 48),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = bg,
	})

	local popup_frame = make("Frame", {
		Name = "ComboPopup",
		Size = UDim2.fromOffset(123, 0),
		BackgroundColor3 = win.Theme.Popup.Color,
		BackgroundTransparency = win.Theme.Popup.Transparency,
		BorderSizePixel = 0,
		Visible = false,
		Parent = win.PopupLayer,
	})
	corner(popup_frame, 4)

	local function refresh_preview()
		preview.Text = selected and truncate(selected, 15) or "Select"
	end

	local function pick(index)
		selected_index = index
		selected = options[index]
		refresh_preview()
		el.Value = selected
		el.Index = selected_index
		if opts.Flag then
			win._flags[opts.Flag] = selected
		end
		safe_call(opts.Callback, selected, selected_index)
	end

	local function build_popup()
		for _, c in ipairs(popup_frame:GetChildren()) do
			if not c:IsA("UICorner") then
				c:Destroy()
			end
		end
		local list = make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = popup_frame,
		})
		local n = #options
		local max_visible = opts.MaxVisible or 8
		local visible = math.min(n, max_visible)
		local item_h = 24
		local full_h = n * item_h + 6
		local shown_h = visible * item_h + 6
		popup_frame.Size = UDim2.fromOffset(123, 0)
		for i, text in ipairs(options) do
			local item = make("TextButton", {
				Name = "Item_" .. text,
				Size = UDim2.new(1, 0, 0, item_h),
				BackgroundColor3 = win.Theme.Element.Color,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
				Parent = popup_frame,
			})
			local item_label = make("TextLabel", {
				Name = "T",
				Position = UDim2.fromOffset(7, 0),
				Size = UDim2.new(1, -14, 1, 0),
				BackgroundTransparency = 1,
				Font = win.Font,
				TextSize = 14,
				Text = text,
				TextColor3 = win.Theme.TextPrimary.Color,
				TextTransparency = i == selected_index and 0 or transp(107),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = item,
			})
			item.MouseEnter:Connect(function()
				tween(item, 0.06, { BackgroundTransparency = win.Theme.ElementHover.Transparency })
			end)
			item.MouseLeave:Connect(function()
				tween(item, 0.08, { BackgroundTransparency = 1 })
			end)
			item.Activated:Connect(function()
				pick(i)
				close_popup(win)
			end)
		end
		return full_h, shown_h
	end

	local function open()
		if win._popup and win._popup.frame == popup_frame then
			close_popup(win)
			return
		end
		local full_h, shown_h = build_popup()
		popup_frame.ClipsDescendants = true
		local target_h = math.min(full_h, shown_h)
		popup_frame.Visible = true
		popup_frame.Size = UDim2.fromOffset(123, 0)
		tween(popup_frame, 0.14, { Size = UDim2.fromOffset(123, target_h) })
		open_popup(win, popup_frame, bg, 126, 40, nil, { preview_update = function(state)
			if state == false then
				preview.TextXAlignment = Enum.TextXAlignment.Left
				preview.Position = UDim2.fromOffset(133, 17)
			end
		end })
	end

	click.Activated:Connect(function()
		open()
	end)

	el.Value = selected
	el.Index = selected_index
	if opts.Flag then
		win._flags[opts.Flag] = selected
	end
	function el:Set(value, silent)
		if type(value) == "number" then
			if options[value] then
				if not silent then
					pick(value)
				else
					selected_index = value
					selected = options[value]
					refresh_preview()
					el.Value = selected
					el.Index = value
					if opts.Flag then
						win._flags[opts.Flag] = selected
					end
				end
			end
		else
			for i, v in ipairs(options) do
				if v == tostring(value) then
					if not silent then
						pick(i)
					else
						selected_index = i
						selected = v
						refresh_preview()
						el.Value = selected
						el.Index = i
						if opts.Flag then
							win._flags[opts.Flag] = selected
						end
					end
				end
			end
		end
	end
	function el:Get()
		return selected
	end
	function el:GetIndex()
		return selected_index
	end
	function el:SetOptions(list)
		options = {}
		for i, v in ipairs(list or {}) do
			options[i] = tostring(v)
		end
		selected_index = 1
		selected = options[1]
		refresh_preview()
	end
	function el:GetOptions()
		local out = {}
		for i, v in ipairs(options) do
			out[i] = v
		end
		return out
	end
	function el:SetLabel(text)
		bg.Label.Text = tostring(text)
	end
	group:_register_flag(opts.Flag, el)
	return el
end

function add_multidropdown(win, group, name, opts)
	opts = opts or {}
	local el, holder = make_element_base(win, group, "multicombo", ELEMENT_HEIGHTS.multicombo)
	local options = {}
	for i, v in ipairs(opts.Options or {}) do
		options[i] = tostring(v)
	end
	local states = {}
	if type(opts.Default) == "table" then
		for _, v in ipairs(opts.Default) do
			states[tostring(v)] = true
		end
	end

	local bg = hover_style(win, make("Frame", {
		Name = "Bg",
		Size = UDim2.fromOffset(256, 48),
		BorderSizePixel = 0,
		Parent = holder,
	}), false)
	corner(bg, 4)
	make("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(110, 18),
		BackgroundTransparency = 1,
		Font = win.Font,
		TextSize = 14,
		Text = tostring(name),
		TextColor3 = win.Theme.TextSecondary.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bg,
	})
	local line1 = make("Frame", {
		Name = "ArrowL",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(234, 24),
		Size = UDim2.fromOffset(6, 1.5),
		BackgroundColor3 = win.Theme.TextPrimary.Color,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Rotation = 45,
		Parent = bg,
	})
	local line2 = make("Frame", {
		Name = "ArrowR",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(239, 23.5),
		Size = UDim2.fromOffset(6, 1.5),
		BackgroundColor3 = win.Theme.TextPrimary.Color,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Rotation = -45,
		Parent = bg,
	})

	local preview = make("TextLabel", {
		Name = "Preview",
		Position = UDim2.fromOffset(133, 17),
		Size = UDim2.fromOffset(87, 16),
		BackgroundTransparency = 1,
		Font = win.Font,
		TextSize = 14,
		Text = "Select",
		TextColor3 = win.Theme.TextPrimary.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Parent = bg,
	})

	local click = make("TextButton", {
		Name = "Hit",
		Size = UDim2.fromOffset(256, 48),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = bg,
	})

	local popup_frame = make("Frame", {
		Name = "MultiPopup",
		Size = UDim2.fromOffset(123, 0),
		BackgroundColor3 = win.Theme.Popup.Color,
		BackgroundTransparency = win.Theme.Popup.Transparency,
		BorderSizePixel = 0,
		Visible = false,
		Parent = win.PopupLayer,
	})
	corner(popup_frame, 4)

	local function build_preview_text()
		local parts = {}
		for _, text in ipairs(options) do
			if states[text] then
				table.insert(parts, text)
			end
		end
		local joined = table.concat(parts, ", ")
		if #joined >= 12 then
			joined = string.sub(joined, 1, 12) .. "..."
		end
		if joined == "" then
			joined = "Select"
		end
		preview.Text = joined
	end

	local function fire()
		local out = {}
		for _, text in ipairs(options) do
			if states[text] then
				table.insert(out, text)
			end
		end
		el.Value = out
		if opts.Flag then
			win._flags[opts.Flag] = out
		end
		safe_call(opts.Callback, out)
	end

	local function build_popup()
		for _, c in ipairs(popup_frame:GetChildren()) do
			if not c:IsA("UICorner") then
				c:Destroy()
			end
		end
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = popup_frame,
		})
		local n = #options
		local max_visible = opts.MaxVisible or 8
		local visible = math.min(n, max_visible)
		local item_h = 24
		local full_h = n * item_h + 6
		local shown_h = visible * item_h + 6
		for i, text in ipairs(options) do
			local item = make("TextButton", {
				Name = "Item_" .. text,
				Size = UDim2.new(1, 0, 0, item_h),
				BackgroundColor3 = win.Theme.Element.Color,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = i,
				Parent = popup_frame,
			})
			local mark = track_accent(win, make("Frame", {
				Name = "Mark",
				Position = UDim2.fromOffset(7, 8),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = win.Theme.Accent,
				BackgroundTransparency = states[text] and 0 or 1,
				BorderSizePixel = 0,
				Parent = item,
			}), "bg")
			corner(mark, 2)
			local item_label = make("TextLabel", {
				Name = "T",
				Position = UDim2.fromOffset(21, 0),
				Size = UDim2.new(1, -28, 1, 0),
				BackgroundTransparency = 1,
				Font = win.Font,
				TextSize = 14,
				Text = text,
				TextColor3 = win.Theme.TextPrimary.Color,
				TextTransparency = states[text] and 0 or transp(107),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = item,
			})
			item.MouseEnter:Connect(function()
				tween(item, 0.06, { BackgroundTransparency = win.Theme.ElementHover.Transparency })
			end)
			item.MouseLeave:Connect(function()
				tween(item, 0.08, { BackgroundTransparency = 1 })
			end)
			item.Activated:Connect(function()
				states[text] = not states[text]
				tween(mark, 0.1, { BackgroundTransparency = states[text] and 0 or 1 })
				tween(item_label, 0.1, { TextTransparency = states[text] and 0 or transp(107) })
				build_preview_text()
				fire()
			end)
		end
		return full_h, shown_h
	end

	local function open()
		if win._popup and win._popup.frame == popup_frame then
			close_popup(win)
			return
		end
		local full_h, shown_h = build_popup()
		popup_frame.ClipsDescendants = true
		local target_h = math.min(full_h, shown_h)
		popup_frame.Visible = true
		popup_frame.Size = UDim2.fromOffset(123, 0)
		tween(popup_frame, 0.14, { Size = UDim2.fromOffset(123, target_h) })
		open_popup(win, popup_frame, bg, 126, 40, nil, {
			preview_update = function(state)
				if state == false then
					build_preview_text()
				end
			end,
		})
	end

	click.Activated:Connect(function()
		open()
	end)

	build_preview_text()
	el.Value = {}
	function el:Set(list, silent)
		states = {}
		for _, v in ipairs(list or {}) do
			states[tostring(v)] = true
		end
		build_preview_text()
		local out = {}
		for _, text in ipairs(options) do
			if states[text] then
				table.insert(out, text)
			end
		end
		el.Value = out
		if opts.Flag then
			win._flags[opts.Flag] = out
		end
		if not silent then
			safe_call(opts.Callback, out)
		end
	end
	function el:Get()
		local out = {}
		for _, text in ipairs(options) do
			if states[text] then
				table.insert(out, text)
			end
		end
		return out
	end
	function el:SetOptions(list)
		options = {}
		for i, v in ipairs(list or {}) do
			options[i] = tostring(v)
		end
		build_preview_text()
	end
	function el:SetLabel(text)
		bg.Label.Text = tostring(text)
	end
	group:_register_flag(opts.Flag, el)
	return el
end
function add_textbox(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "textbox", ELEMENT_HEIGHTS.textbox)
        local bg = hover_style(win, make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(256, 48),
                BorderSizePixel = 0,
                Parent = holder,
        }), false)
        corner(bg, 4)
        make("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(12, 16),
                Size = UDim2.fromOffset(110, 18),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(name),
                TextColor3 = win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = bg,
        })
        local frame = make("Frame", {
                Name = "Field",
                Position = UDim2.fromOffset(142, 9),
                Size = UDim2.fromOffset(105, 30),
                BackgroundColor3 = win.Theme.ElementInner.Color,
                BackgroundTransparency = win.Theme.ElementInner.Transparency,
                BorderSizePixel = 0,
                Parent = bg,
        })
        corner(frame, 4)
        local box = make("TextBox", {
                Name = "Input",
                Position = UDim2.fromOffset(10, 7),
                Size = UDim2.fromOffset(85, 16),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = opts.Default and tostring(opts.Default) or "",
                PlaceholderText = opts.Placeholder and tostring(opts.Placeholder) or "",
                PlaceholderColor3 = win.Theme.TextMuted.Color,
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = frame,
        })

        local value = opts.Default and tostring(opts.Default) or ""
        el.Value = value
        if opts.Flag then
                win._flags[opts.Flag] = value
        end

        box.Focused:Connect(function()
                win._text_focus = win._text_focus + 1
        end)
        box.FocusLost:Connect(function(enter)
                win._text_focus = math.max(0, win._text_focus - 1)
                local text = box.Text
                if opts.OnlyNumbers then
                        local num = tonumber(text)
                        if not num then
                                box.Text = value
                                return
                        end
                        text = tostring(num)
                end
                if text == value then
                        return
                end
                value = text
                el.Value = value
                if opts.Flag then
                        win._flags[opts.Flag] = value
                end
                if enter then
                        safe_call(opts.OnEnter, value)
                end
                safe_call(opts.Callback, value)
                safe_call(opts.OnChanged, value)
        end)

        function el:Set(text, silent)
                text = tostring(text)
                if opts.OnlyNumbers then
                        local num = tonumber(text)
                        if not num then
                                return
                        end
                        text = tostring(num)
                end
                value = text
                box.Text = text
                el.Value = value
                if opts.Flag then
                        win._flags[opts.Flag] = value
                end
                if not silent then
                        safe_call(opts.Callback, value)
                end
        end
        function el:Get()
                return value
        end
        function el:SetPlaceholder(text)
                box.PlaceholderText = tostring(text)
        end
        function el:SetLabel(text)
                bg.Label.Text = tostring(text)
        end
        group:_register_flag(opts.Flag, el)
        return el
end

function add_keybind(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "keybind", ELEMENT_HEIGHTS.keybind)
        local bg = hover_style(win, make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(256, 48),
                BorderSizePixel = 0,
                Parent = holder,
        }), false)
        corner(bg, 4)
        make("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(12, 16),
                Size = UDim2.fromOffset(130, 18),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(name),
                TextColor3 = win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = bg,
        })
        local frame = make("Frame", {
                Name = "Field",
                Position = UDim2.fromOffset(185, 9),
                Size = UDim2.fromOffset(62, 30),
                BackgroundColor3 = win.Theme.ElementInner.Color,
                BackgroundTransparency = win.Theme.ElementInner.Transparency,
                BorderSizePixel = 0,
                Parent = bg,
        })
        corner(frame, 4)
        local frame_label = make("TextLabel", {
                Name = "KeyText",
                Size = UDim2.fromOffset(62, 30),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = "None",
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                Parent = frame,
        })

        local bind = {
                Key = nil,
                Mode = opts.Mode or "Hold",
                Active = false,
                Toggled = false,
        }
        if opts.Default then
                bind.Key = opts.Default
        end
        if type(opts.Mode) == "number" then
                bind.Mode = ({ "Always", "Hold", "Toggle" })[opts.Mode] or "Hold"
        end
        el.Bind = bind

        local capturing = false

        local function refresh_label()
                if capturing then
                        frame_label.Text = "..."
                elseif bind.Mode == "Always" then
                        frame_label.Text = "Always"
                elseif bind.Key then
                        frame_label.Text = key_to_string(bind)
                else
                        frame_label.Text = "None"
                end
        end
        refresh_label()

        local function resolve_state()
                local prev = bind.Active
                if bind.Mode == "Always" then
                        bind.Active = true
                elseif bind.Mode == "Hold" then
                        bind.Active = bind.Held == true
                else
                        bind.Active = bind.Toggled == true
                end
                if prev ~= bind.Active then
                        el.Value = bind.Active
                        if opts.Flag then
                                win._flags[opts.Flag] = bind.Active
                        end
                        safe_call(opts.Callback, bind.Active)
                        win:RefreshKeybindList()
                end
        end

        local function open_mode_popup()
                local popup_frame = make("Frame", {
                        Name = "ModePopup",
                        Size = UDim2.fromOffset(63, 78),
                        BackgroundColor3 = win.Theme.Popup.Color,
                        BackgroundTransparency = win.Theme.Popup.Transparency,
                        BorderSizePixel = 0,
                        Visible = true,
                        Parent = win.PopupLayer,
                })
                corner(popup_frame, 4)
                make("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Parent = popup_frame,
                })
                local modes = { "Always", "Hold", "Toggle" }
                for i, mode in ipairs(modes) do
                        local item = make("TextButton", {
                                Name = "Mode_" .. mode,
                                Size = UDim2.new(1, 0, 0, 24),
                                BackgroundColor3 = win.Theme.Element.Color,
                                BackgroundTransparency = 1,
                                Text = "",
                                AutoButtonColor = false,
                                LayoutOrder = i,
                                Parent = popup_frame,
                        })
                        local lbl = make("TextLabel", {
                                Name = "T",
                                Position = UDim2.fromOffset(7, 0),
                                Size = UDim2.new(1, -14, 1, 0),
                                BackgroundTransparency = 1,
                                Font = win.Font,
                                TextSize = 14,
                                Text = mode,
                                TextColor3 = win.Theme.TextPrimary.Color,
                                TextTransparency = bind.Mode == mode and 0 or transp(107),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Parent = item,
                        })
                        item.MouseEnter:Connect(function()
                                tween(item, 0.06, { BackgroundTransparency = win.Theme.ElementHover.Transparency })
                        end)
                        item.MouseLeave:Connect(function()
                                tween(item, 0.08, { BackgroundTransparency = 1 })
                        end)
                        item.Activated:Connect(function()
                                bind.Mode = mode
                                if mode == "Toggle" and bind.Toggled == nil then
                                        bind.Toggled = false
                                end
                                refresh_label()
                                resolve_state()
                                close_popup(win)
                        end)
                end
                open_popup(win, popup_frame, frame, 0, 31, nil, {})
        end

        table.insert(win._conns, frame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        capturing = true
                        refresh_label()
                elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
                        open_mode_popup()
                end
        end))

        table.insert(win._conns, UserInputService.InputBegan:Connect(function(input, processed)
                if capturing then
                        if input.KeyCode == Enum.KeyCode.Escape then
                                bind.Key = nil
                                capturing = false
                                bind.Held = false
                                resolve_state()
                                refresh_label()
                                return
                        end
                        if input_is_mouse_button(input.UserInputType) then
                                bind.Key = input
                        elseif input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
                                bind.Key = input
                        end
                        if bind.Key then
                                capturing = false
                                bind.Held = true
                                refresh_label()
                                resolve_state()
                                win:RefreshKeybindList()
                        end
                        return
                end
                if processed and not input_is_mouse_button(input.UserInputType) then
                        return
                end
                if not bind.Key then
                        return
                end
                local same = false
                if input.KeyCode and bind.Key.KeyCode and input.KeyCode == bind.Key.KeyCode then
                        same = true
                end
                if input.UserInputType and bind.Key.UserInputType and input.UserInputType == bind.Key.UserInputType then
                        same = true
                end
                if same and not capturing then
                        if bind.Mode == "Hold" then
                                bind.Held = true
                                resolve_state()
                        elseif bind.Mode == "Toggle" then
                                bind.Toggled = not (bind.Toggled == true)
                                resolve_state()
                        end
                end
        end))

        table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
                if bind.Mode == "Hold" and bind.Key then
                        local same = false
                        if input.KeyCode and bind.Key.KeyCode and input.KeyCode == bind.Key.KeyCode then
                                same = true
                        end
                        if input.UserInputType and bind.Key.UserInputType and input.UserInputType == bind.Key.UserInputType then
                                same = true
                        end
                        if same then
                                bind.Held = false
                                resolve_state()
                        end
                end
        end))

        el.Value = false
        function el:SetMode(mode)
                if type(mode) == "number" then
                        mode = ({ "Always", "Hold", "Toggle" })[mode] or "Hold"
                end
                bind.Mode = tostring(mode)
                refresh_label()
                resolve_state()
        end
        function el:GetMode()
                return bind.Mode
        end
        function el:SetKey(input_obj)
                bind.Key = input_obj
                refresh_label()
        end
        function el:GetKey()
                return bind.Key
        end
        function el:SetActive(state)
                if bind.Mode == "Toggle" then
                        bind.Toggled = state == true
                elseif bind.Mode == "Hold" then
                        bind.Held = state == true
                end
                resolve_state()
        end
        function el:IsActive()
                return bind.Active
        end
        function el:Rebind()
                capturing = true
                refresh_label()
        end
        group:_register_flag(opts.Flag, el)
        table.insert(win._binds, { name = name, el = el })
        return el
end

function add_listbox(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "listbox", 40)
        local items = {}
        for i, v in ipairs(opts.Options or {}) do
                items[i] = tostring(v)
        end
        local height = opts.Height or math.min(#items * 40 + 8, 190)
        height = math.max(height, 48)
        holder.Size = UDim2.new(1, 0, 0, height)

        local bg = make("Frame", {
                Name = "Bg",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = win.Theme.Element.Color,
                BackgroundTransparency = win.Theme.Element.Transparency,
                BorderSizePixel = 0,
                Parent = holder,
        })
        corner(bg, 4)

        local scroll = make("ScrollingFrame", {
                Name = "List",
                Position = UDim2.fromOffset(6, 4),
                Size = UDim2.new(1, -12, 1, -8),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageTransparency = 0.8,
                CanvasSize = UDim2.fromOffset(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                ClipsDescendants = true,
                Parent = bg,
        })
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 4),
                Parent = scroll,
        })

        local multi = opts.Multi == true
        local selected_index = 0
        local states = {}
        el.Value = multi and {} or nil

        local function rebuild()
                for _, c in ipairs(scroll:GetChildren()) do
                        if not c:IsA("UIListLayout") then
                                c:Destroy()
                        end
                end
                for i, text in ipairs(items) do
                        local item = make("TextButton", {
                                Name = "Item_" .. text,
                                Size = UDim2.new(1, 0, 0, 36),
                                BackgroundColor3 = win.Theme.Element.Color,
                                BackgroundTransparency = 1,
                                Text = "",
                                AutoButtonColor = false,
                                LayoutOrder = i,
                                Parent = scroll,
                        })
                        corner(item, 4)
                        local item_label = make("TextLabel", {
                                Name = "T",
                                Position = UDim2.fromOffset(11, 8),
                                Size = UDim2.new(1, -22, 0, 20),
                                BackgroundTransparency = 1,
                                Font = win.Font,
                                TextSize = 14,
                                Text = text,
                                TextColor3 = win.Theme.TextPrimary.Color,
                                TextTransparency = transp(107),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextTruncate = Enum.TextTruncate.AtEnd,
                                Parent = item,
                        })
                        local function selected_now()
                                if multi then
                                        return states[text] == true
                                end
                                return selected_index == i
                        end
                        if selected_now() then
                                item.BackgroundTransparency = win.Theme.ElementHover.Transparency
                                item_label.TextTransparency = 0
                        end
                        item.MouseEnter:Connect(function()
                                tween(item, 0.06, { BackgroundTransparency = win.Theme.ElementHover.Transparency })
                        end)
                        item.MouseLeave:Connect(function()
                                if not selected_now() then
                                        tween(item, 0.08, { BackgroundTransparency = 1 })
                                end
                        end)
                        item.Activated:Connect(function()
                                if multi then
                                        states[text] = not states[text]
                                        local out = {}
                                        for _, t in ipairs(items) do
                                                if states[t] then
                                                        table.insert(out, t)
                                                end
                                        end
                                        el.Value = out
                                        if opts.Flag then
                                                win._flags[opts.Flag] = out
                                        end
                                        if states[text] then
                                                item.BackgroundTransparency = win.Theme.ElementHover.Transparency
                                                item_label.TextTransparency = 0
                                        else
                                                tween(item, 0.08, { BackgroundTransparency = 1 })
                                                tween(item_label, 0.08, { TextTransparency = transp(107) })
                                        end
                                        safe_call(opts.Callback, out)
                                else
                                        local prev = selected_index
                                        selected_index = i
                                        if prev ~= i and prev >= 1 and prev <= #items then
                                                local prev_btn = scroll:FindFirstChild("Item_" .. items[prev])
                                                if prev_btn then
                                                        local prev_label = prev_btn:FindFirstChild("T")
                                                        prev_btn.BackgroundTransparency = 1
                                                        if prev_label then
                                                                prev_label.TextTransparency = transp(107)
                                                        end
                                                end
                                        end
                                        item.BackgroundTransparency = win.Theme.ElementHover.Transparency
                                        item_label.TextTransparency = 0
                                        el.Value = text
                                        el.Index = i
                                        if opts.Flag then
                                                win._flags[opts.Flag] = text
                                        end
                                        safe_call(opts.Callback, text, i)
                                end
                        end)
                end
        end
        rebuild()

        function el:SetOptions(list)
                items = {}
                for i, v in ipairs(list or {}) do
                        items[i] = tostring(v)
                end
                selected_index = 0
                states = {}
                rebuild()
        end
        function el:GetOptions()
                local out = {}
                for i, v in ipairs(items) do
                        out[i] = v
                end
                return out
        end
        function el:Add(text)
                table.insert(items, tostring(text))
                rebuild()
        end
        function el:Clear()
                items = {}
                selected_index = 0
                states = {}
                rebuild()
        end
        function el:Set(value)
                if multi then
                        states = {}
                        for _, v in ipairs(value or {}) do
                                states[tostring(v)] = true
                        end
                        rebuild()
                else
                        for i, v in ipairs(items) do
                                if v == tostring(value) then
                                        selected_index = i
                                        el.Value = v
                                        el.Index = i
                                        rebuild()
                                end
                        end
                end
        end
        function el:Get()
                if multi then
                        local out = {}
                        for _, t in ipairs(items) do
                                if states[t] then
                                        table.insert(out, t)
                                end
                        end
                        return out
                end
                return el.Value
        end
        group:_register_flag(opts.Flag, el)
        return el
end
function add_colorpicker(win, group, name, opts)
        opts = opts or {}
        local el, holder = make_element_base(win, group, "colorpicker", ELEMENT_HEIGHTS.colorpicker)
        local def_color = opts.Default or rgb(255, 255, 255)
        local def_alpha = opts.DefaultAlpha or 1
        if opts.NoAlpha then
                def_alpha = 1
        end

        local bg = hover_style(win, make("Frame", {
                Name = "Bg",
                Size = UDim2.fromOffset(256, 48),
                BorderSizePixel = 0,
                Parent = holder,
        }), false)
        corner(bg, 4)
        make("TextLabel", {
                Name = "Label",
                Position = UDim2.fromOffset(12, 16),
                Size = UDim2.fromOffset(180, 18),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(name),
                TextColor3 = win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = bg,
        })

        local swatch = make("TextButton", {
                Name = "Swatch",
                Position = UDim2.fromOffset(209, 15),
                Size = UDim2.fromOffset(32, 16),
                BackgroundColor3 = rgb(30, 30, 30),
                BackgroundTransparency = 0,
                Text = "",
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = bg,
        })
        corner(swatch, 4)
        local swatch_color = make("Frame", {
                Name = "Color",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = def_color,
                BackgroundTransparency = 1 - def_alpha,
                BorderSizePixel = 0,
                Parent = swatch,
        })
        corner(swatch_color, 4)

        local h, s, v = rgb_hsv(def_color.R * 255, def_color.G * 255, def_color.B * 255)
        local alpha_v = def_alpha
        el.Value = def_color
        el.Alpha = def_alpha

        local function fire()
                el.Value = hsv_rgb(h, s, v)
                el.Alpha = alpha_v
                if opts.Flag then
                        win._flags[opts.Flag] = { R = el.Value.R, G = el.Value.G, B = el.Value.B, A = alpha_v }
                end
                safe_call(opts.Callback, el.Value, alpha_v)
        end

        local function refresh_swatch()
                swatch_color.BackgroundColor3 = hsv_rgb(h, s, v)
                swatch_color.BackgroundTransparency = clamp(1 - alpha_v, 0, 1)
        end

        local popup_frame = make("Frame", {
                Name = "PickerPopup",
                Size = UDim2.fromOffset(244, 258),
                BackgroundColor3 = win.Theme.Picker.Color,
                BackgroundTransparency = win.Theme.Picker.Transparency,
                BorderSizePixel = 0,
                Visible = false,
                Parent = win.PopupLayer,
        })
        corner(popup_frame, 10)

        local sv = make("Frame", {
                Name = "SV",
                Position = UDim2.fromOffset(10, 10),
                Size = UDim2.fromOffset(176, 176),
                BackgroundColor3 = hsv_rgb(h, 1, 1),
                BorderSizePixel = 0,
                Parent = popup_frame,
        })
        corner(sv, 2)
        local sv_white = make("Frame", {
                Name = "White",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = rgb(255, 255, 255),
                BorderSizePixel = 0,
                Parent = sv,
        })
        gradient(sv_white, rgb(255, 255, 255), 0, 1, 0)
        local sv_black = make("Frame", {
                Name = "Black",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = rgb(0, 0, 0),
                BorderSizePixel = 0,
                Parent = sv,
        })
        gradient(sv_black, rgb(0, 0, 0), 1, 0, 90)
        local sv_cursor = make("Frame", {
                Name = "Cursor",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(8, 8),
                BackgroundColor3 = rgb(255, 255, 255),
                BorderSizePixel = 0,
                Parent = sv,
        })
        corner(sv_cursor, 4)
        stroke(sv_cursor, rgb(0, 0, 0), 0.2, 1)

        local hue_bar = make("Frame", {
                Name = "Hue",
                Position = UDim2.fromOffset(194, 10),
                Size = UDim2.fromOffset(14, 176),
                BackgroundColor3 = rgb(255, 255, 255),
                BorderSizePixel = 0,
                Parent = popup_frame,
        })
        corner(hue_bar, 2)
        local hue_grad = make("UIGradient", {
                Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, rgb(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.17, rgb(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.33, rgb(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5, rgb(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.66, rgb(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.83, rgb(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, rgb(255, 0, 0)),
                }),
                Rotation = 90,
                Parent = hue_bar,
        })
        local hue_cursor = make("Frame", {
                Name = "Cursor",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0, h * 176),
                Size = UDim2.fromOffset(18, 2),
                BackgroundColor3 = rgb(255, 255, 255),
                BorderSizePixel = 0,
                Parent = hue_bar,
        })
        stroke(hue_cursor, rgb(0, 0, 0), 0.2, 1)

        local alpha_bar = nil
        local alpha_cursor = nil
        if not opts.NoAlpha then
                alpha_bar = make("Frame", {
                        Name = "Alpha",
                        Position = UDim2.fromOffset(214, 10),
                        Size = UDim2.fromOffset(14, 176),
                        BackgroundColor3 = hsv_rgb(h, s, v),
                        BorderSizePixel = 0,
                        Parent = popup_frame,
                })
                corner(alpha_bar, 2)
                local a_grad = make("UIGradient", {
                        Color = ColorSequence.new(rgb(255, 255, 255)),
                        Transparency = NumberSequence.new({
                                NumberSequenceKeypoint.new(0, 0),
                                NumberSequenceKeypoint.new(1, 1),
                        }),
                        Rotation = 90,
                        Parent = alpha_bar,
                })
                el._alpha_grad = a_grad
                alpha_cursor = make("Frame", {
                        Name = "Cursor",
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new(0.5, 0, 0, (1 - alpha_v) * 176),
                        Size = UDim2.fromOffset(18, 2),
                        BackgroundColor3 = rgb(255, 255, 255),
                        BorderSizePixel = 0,
                        Parent = alpha_bar,
                })
                stroke(alpha_cursor, rgb(0, 0, 0), 0.2, 1)
        end

        local rgb_label = make("TextLabel", {
                Name = "RGBText",
                Position = UDim2.fromOffset(10, 194),
                Size = UDim2.fromOffset(224, 16),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 13,
                Text = "",
                TextColor3 = win.Theme.TextSecondary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = popup_frame,
        })

        local function refresh_rgb_text()
                local c = hsv_rgb(h, s, v)
                rgb_label.Text = string.format("R %d  G %d  B %d  A %d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), math.floor(alpha_v * 255 + 0.5))
        end

        local function refresh_all()
                local c = hsv_rgb(h, s, v)
                sv.BackgroundColor3 = hsv_rgb(h, 1, 1)
                sv_cursor.Position = UDim2.fromOffset(s * 176, (1 - v) * 176)
                hue_cursor.Position = UDim2.new(0.5, 0, 0, h * 176)
                if alpha_bar then
                        alpha_bar.BackgroundColor3 = c
                        alpha_cursor.Position = UDim2.new(0.5, 0, 0, (1 - alpha_v) * 176)
                end
                swatch_color.BackgroundColor3 = c
                swatch_color.BackgroundTransparency = clamp(1 - alpha_v, 0, 1)
                refresh_rgb_text()
        end

        local function sv_drag()
                pcall(function()
                        local mx, my = mouse_pos()
                        local ap = sv.AbsolutePosition
                        local as = sv.AbsoluteSize
                        s = clamp((mx - ap.X) / as.X, 0, 1)
                        v = clamp(1 - (my - ap.Y) / as.Y, 0, 1)
                        refresh_all()
                        fire()
                end)
        end

        local function hue_drag()
                pcall(function()
                        local mx, my = mouse_pos()
                        local ap = hue_bar.AbsolutePosition
                        local as = hue_bar.AbsoluteSize
                        h = clamp((my - ap.Y) / as.Y, 0, 1)
                        if h >= 1 then
                                h = 0.999
                        end
                        refresh_all()
                        fire()
                end)
        end

        local function alpha_drag()
                if not alpha_bar then
                        return
                end
                pcall(function()
                        local mx, my = mouse_pos()
                        local ap = alpha_bar.AbsolutePosition
                        local as = alpha_bar.AbsoluteSize
                        alpha_v = clamp(1 - (my - ap.Y) / as.Y, 0, 1)
                        refresh_all()
                        fire()
                end)
        end

        local function bind_drag(frame, fn)
                local dragging = false
                frame.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                dragging = true
                                fn()
                        end
                end)
                table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
                        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                                fn()
                        end
                end))
                table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                                dragging = false
                        end
                end))
        end

        bind_drag(sv, sv_drag)
        bind_drag(hue_bar, hue_drag)
        if alpha_bar then
                bind_drag(alpha_bar, alpha_drag)
        end

        local function copy_color()
                local c = hsv_rgb(h, s, v)
                local str = string.format("%d,%d,%d,%d", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5), math.floor(alpha_v * 255 + 0.5))
                local setter = get_clipboard()
                if setter then
                        pcall(setter, str)
                end
                close_popup(win)
        end

        local function paste_color()
                local reader = read_clipboard()
                if not reader or reader == "" then
                        return
                end
                local nums = {}
                for num in string.gmatch(reader, "(-?%d+%.?%d*)") do
                        table.insert(nums, tonumber(num))
                end
                if #nums >= 3 then
                        local r, g, b = nums[1], nums[2], nums[3]
                        h, s, v = rgb_hsv(r, g, b)
                        if #nums >= 4 then
                                alpha_v = clamp(nums[4] / 255, 0, 1)
                        end
                        refresh_all()
                        fire()
                        close_popup(win)
                end
        end

        local copy_btn = make("TextButton", {
                Name = "Copy",
                Position = UDim2.fromOffset(10, 222),
                Size = UDim2.fromOffset(76, 24),
                BackgroundColor3 = rgb(35, 35, 35),
                BackgroundTransparency = 0.69,
                Text = "Copy",
                Font = win.Font,
                TextSize = 14,
                TextColor3 = win.Theme.TextPrimary.Color,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = popup_frame,
        })
        corner(copy_btn, 2)
        local paste_btn = make("TextButton", {
                Name = "Paste",
                Position = UDim2.fromOffset(91, 222),
                Size = UDim2.fromOffset(76, 24),
                BackgroundColor3 = rgb(35, 35, 35),
                BackgroundTransparency = 0.69,
                Text = "Paste",
                Font = win.Font,
                TextSize = 14,
                TextColor3 = win.Theme.TextPrimary.Color,
                AutoButtonColor = false,
                BorderSizePixel = 0,
                Parent = popup_frame,
        })
        corner(paste_btn, 2)

        copy_btn.MouseEnter:Connect(function()
                tween(copy_btn, 0.06, { BackgroundTransparency = 0.57 })
        end)
        copy_btn.MouseLeave:Connect(function()
                tween(copy_btn, 0.08, { BackgroundTransparency = 0.69 })
        end)
        paste_btn.MouseEnter:Connect(function()
                tween(paste_btn, 0.06, { BackgroundTransparency = 0.57 })
        end)
        paste_btn.MouseLeave:Connect(function()
                tween(paste_btn, 0.08, { BackgroundTransparency = 0.69 })
        end)
        copy_btn.Activated:Connect(copy_color)
        paste_btn.Activated:Connect(paste_color)

        swatch.Activated:Connect(function()
                if win._popup and win._popup.frame == popup_frame then
                        close_popup(win)
                        return
                end
                refresh_all()
                popup_frame.Visible = true
                popup_frame.ClipsDescendants = false
                open_popup(win, popup_frame, bg, 35, -38, nil, {})
        end)

        refresh_all()
        refresh_rgb_text()

        function el:SetColor(c, a, silent)
                h, s, v = rgb_hsv(c.R * 255, c.G * 255, c.B * 255)
                if a ~= nil then
                        alpha_v = clamp(a, 0, 1)
                end
                refresh_all()
                el.Value = hsv_rgb(h, s, v)
                el.Alpha = alpha_v
                if opts.Flag then
                        win._flags[opts.Flag] = { R = el.Value.R, G = el.Value.G, B = el.Value.B, A = alpha_v }
                end
                if not silent then
                        safe_call(opts.Callback, el.Value, alpha_v)
                end
        end
        function el:GetColor()
                return hsv_rgb(h, s, v)
        end
        function el:GetAlpha()
                return alpha_v
        end
        function el:SetLabel(text)
                bg.Label.Text = tostring(text)
        end
        group:_register_flag(opts.Flag, el)
        return el
end

local function build_watermark(win)
        if win._chrome.Watermark then
                win._chrome.Watermark:Destroy()
                win._chrome.Watermark = nil
        end
        if win.WatermarkEnabled == false then
                return
        end
        local cfg = win.WatermarkConfig or {}
        local wm = make("Frame", {
                Name = "Watermark",
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -10, 0, 10),
                Size = UDim2.fromOffset(0, 32),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = win.Theme.Body.Color,
                BackgroundTransparency = win.Theme.Body.Transparency,
                BorderSizePixel = 0,
                Parent = win.ScreenGui,
        })
        corner(wm, 3)
        stroke(wm, win.Theme.Border.Color, win.Theme.Border.Transparency, 1)

        local left = make("Frame", {
                Name = "Left",
                Size = UDim2.fromOffset(0, 29),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = win.Theme.Header.Color,
                BackgroundTransparency = win.Theme.Header.Transparency,
                BorderSizePixel = 0,
                Parent = wm,
        })
        corner(left, 3)
        local left_layout = make("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = left,
        })
        make("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                Parent = left,
        })

        local icon_holder = make("Frame", {
                Name = "Icon",
                Size = UDim2.fromOffset(16, 16),
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Parent = left,
        })
        set_icon_display(win, icon_holder, win.Icon, 16, win.Theme.Accent)

        local prefix_label = make("TextLabel", {
                Name = "Prefix",
                Size = UDim2.fromOffset(0, 16),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = win.Name,
                TextColor3 = win.Theme.TextPrimary.Color,
                LayoutOrder = 2,
                Parent = left,
        })

        local right = make("Frame", {
                Name = "Right",
                Size = UDim2.fromOffset(0, 29),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                Parent = wm,
        })
        local right_layout = make("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 0),
                Parent = right,
        })
        make("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                Parent = right,
        })
        local info_label = make("TextLabel", {
                Name = "Info",
                Size = UDim2.fromOffset(0, 16),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = "",
                TextColor3 = win.Theme.TextPrimary.Color,
                TextTransparency = 0.15,
                LayoutOrder = 1,
                Parent = right,
        })

        win._chrome.Watermark = wm
        win._watermark_info = info_label

        local user = cfg.User
        if not user and LocalPlayer then
                user = LocalPlayer.Name
        end
        user = user or "user"
        local fps = 0
        local frames = 0
        local last = os.clock()
        table.insert(win._conns, RunService.RenderStepped:Connect(function()
                frames = frames + 1
                local now = os.clock()
                if now - last >= 0.5 then
                        fps = math.floor(frames / (now - last) + 0.5)
                        frames = 0
                        last = now
                        if win.Open and win._chrome.Watermark then
                                local parts = {}
                                table.insert(parts, user)
                                table.insert(parts, os.date("%H:%M"))
                                if cfg.ShowPing then
                                        local ping = try(function()
                                                return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
                                        end) or 0
                                        table.insert(parts, ping .. "ms")
                                end
                                if cfg.ShowFPS ~= false then
                                        table.insert(parts, "fps " .. fps)
                                end
                                info_label.Text = table.concat(parts, " | ")
                        end
                end
        end))

        local dragging = false
        local start_pos = nil
        local start_input = nil
        wm.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        start_pos = wm.Position
                        start_input = input.Position
                end
        end)
        table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        wm.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + (input.Position.X - start_input.X), start_pos.Y.Scale, start_pos.Y.Offset + (input.Position.Y - start_input.Y))
                end
        end))
        table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                end
        end))

        win._watermark_user = user
end

local function build_keybind_list(win)
        if win._chrome.KeybindsList then
                win._chrome.KeybindsList:Destroy()
                win._chrome.KeybindsList = nil
        end
        if win.KeybindsEnabled == false then
                return
        end
        local cfg = win.KeybindsConfig or {}
        local kb = make("Frame", {
                Name = "KeybindsList",
                Position = UDim2.fromOffset(cfg.X or 10, cfg.Y or 200),
                Size = UDim2.fromOffset(176, 40),
                BackgroundColor3 = win.Theme.Body.Color,
                BackgroundTransparency = win.Theme.Body.Transparency,
                BorderSizePixel = 0,
                Parent = win.ScreenGui,
        })
        corner(kb, 4)
        stroke(kb, win.Theme.Border.Color, win.Theme.Border.Transparency, 1)

        local header = make("Frame", {
                Name = "Header",
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = win.Theme.Header.Color,
                BackgroundTransparency = win.Theme.Header.Transparency,
                BorderSizePixel = 0,
                Parent = kb,
        })
        corner(header, 4)

        local icon = make("Frame", {
                Name = "Icon",
                Position = UDim2.fromOffset(51, 9),
                Size = UDim2.fromOffset(16, 16),
                BackgroundColor3 = win.Theme.TextPrimary.Color,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Parent = header,
        })
        corner(icon, 2)
        make("Frame", {
                Name = "Key1",
                Position = UDim2.fromOffset(3, 4),
                Size = UDim2.fromOffset(10, 2),
                BackgroundColor3 = win.Theme.TextPrimary.Color,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Parent = icon,
        })
        make("Frame", {
                Name = "Key2",
                Position = UDim2.fromOffset(3, 10),
                Size = UDim2.fromOffset(6, 2),
                BackgroundColor3 = win.Theme.TextPrimary.Color,
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Parent = icon,
        })

        make("TextLabel", {
                Name = "Title",
                Position = UDim2.fromOffset(75, 8),
                Size = UDim2.fromOffset(90, 16),
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = "keybinds",
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = header,
        })

        local line = make("Frame", {
                Name = "Line",
                Position = UDim2.fromOffset(0, 31),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = win.Theme.Separator.Color,
                BackgroundTransparency = win.Theme.Separator.Transparency,
                BorderSizePixel = 0,
                Parent = kb,
        })

        local list_holder = make("Frame", {
                Name = "Items",
                Position = UDim2.fromOffset(0, 34),
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Parent = kb,
        })
        make("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = list_holder,
        })

        win._chrome.KeybindsList = kb
        win._keybinds_items = list_holder

        local dragging = false
        local start_pos = nil
        local start_input = nil
        header.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        start_pos = kb.Position
                        start_input = input.Position
                end
        end)
        table.insert(win._conns, UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        kb.Position = UDim2.new(start_pos.X.Scale, start_pos.X.Offset + (input.Position.X - start_input.X), start_pos.Y.Scale, start_pos.Y.Offset + (input.Position.Y - start_input.Y))
                end
        end))
        table.insert(win._conns, UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                end
        end))
end

local function refresh_keybind_list(win)
        local holder = win._keybinds_items
        if not holder then
                return
        end
        for _, c in ipairs(holder:GetChildren()) do
                if not c:IsA("UIListLayout") then
                        c:Destroy()
                end
        end
        local any = false
        for i, entry in ipairs(win._binds) do
                local bind = entry.el.Bind
                if bind.Active and bind.Key then
                        any = true
                        local item = make("Frame", {
                                Name = "Bind_" .. entry.name,
                                Size = UDim2.new(1, 0, 0, 25),
                                BackgroundTransparency = 1,
                                LayoutOrder = i,
                                Parent = holder,
                        })
                        make("TextLabel", {
                                Name = "Name",
                                Position = UDim2.fromOffset(16, 4),
                                Size = UDim2.fromOffset(100, 18),
                                BackgroundTransparency = 1,
                                Font = win.Font,
                                TextSize = 14,
                                Text = entry.name,
                                TextColor3 = win.Theme.TextPrimary.Color,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextTruncate = Enum.TextTruncate.AtEnd,
                                Parent = item,
                        })
                        local type_text = "[ hold ]"
                        if bind.Mode == "Always" then
                                type_text = "[ enabled ]"
                        elseif bind.Mode == "Toggle" then
                                type_text = "[ toggled ]"
                        end
                        make("TextLabel", {
                                Name = "Type",
                                AnchorPoint = Vector2.new(1, 0),
                                Position = UDim2.new(1, -15, 0, 4),
                                Size = UDim2.fromOffset(90, 18),
                                BackgroundTransparency = 1,
                                Font = win.Font,
                                TextSize = 14,
                                Text = type_text,
                                TextColor3 = win.Theme.TextPrimary.Color,
                                TextTransparency = 0.6,
                                TextXAlignment = Enum.TextXAlignment.Right,
                                Parent = item,
                        })
                end
        end
        local kb = win._chrome.KeybindsList
        if kb then
                kb.Visible = win.Open or any
        end
end

local function notify(win, text, duration)
        local n = make("Frame", {
                Name = "Notify",
                AnchorPoint = Vector2.new(0.5, 1),
                Position = UDim2.new(0.5, 0, 1, -20),
                Size = UDim2.fromOffset(0, 34),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = win.Theme.Popup.Color,
                BackgroundTransparency = win.Theme.Popup.Transparency,
                BorderSizePixel = 0,
                Parent = win.ScreenGui,
                ZIndex = 100,
        })
        corner(n, 4)
        local n_stroke = stroke(n, win.Theme.Border.Color, win.Theme.Border.Transparency, 1)
        local bar = make("Frame", {
                Name = "AccentBar",
                Position = UDim2.fromOffset(0, 8),
                Size = UDim2.fromOffset(2, 18),
                BackgroundColor3 = win.Theme.Accent,
                BorderSizePixel = 0,
                Parent = n,
        })
        track_accent(win, bar, "bg")
        local label = make("TextLabel", {
                Name = "Text",
                Position = UDim2.fromOffset(14, 0),
                Size = UDim2.fromOffset(0, 34),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Font = win.Font,
                TextSize = 14,
                Text = tostring(text),
                TextColor3 = win.Theme.TextPrimary.Color,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = n,
        })
        make("UIPadding", {
                PaddingRight = UDim.new(0, 16),
                Parent = label,
        })
        task.delay(duration or 2.5, function()
                if n.Parent then
                        local tw = tween(n, 0.25, { BackgroundTransparency = 1 })
                        tween(label, 0.25, { TextTransparency = 1 })
                        tween(bar, 0.25, { BackgroundTransparency = 1 })
                        tween(n_stroke, 0.25, { Transparency = 1 })
                        tw.Completed:Connect(function()
                                n:Destroy()
                        end)
                end
        end)
end
local function create_tab_object(win, name, opts)
        opts = opts or {}
        local tab = {}
        tab.Name = tostring(name)
        tab.SubTabs = {}
        tab.CurrentSub = nil
        tab.LastSub = 1

        local root
        if HAS_CG then
                root = make("CanvasGroup", {
                        Name = "Tab_" .. tab.Name,
                        Position = UDim2.fromOffset(160, 47),
                        Size = UDim2.fromOffset(560, 473),
                        BackgroundTransparency = 1,
                        GroupTransparency = 0,
                        Visible = false,
                        BorderSizePixel = 0,
                        Parent = win.Root,
                })
        else
                root = make("Frame", {
                        Name = "Tab_" .. tab.Name,
                        Position = UDim2.fromOffset(160, 47),
                        Size = UDim2.fromOffset(560, 473),
                        BackgroundTransparency = 1,
                        Visible = false,
                        BorderSizePixel = 0,
                        Parent = win.Root,
                })
        end
        tab.Root = root

        local row = make("Frame", {
                Name = "SubRow",
                Position = UDim2.fromOffset(18, 15),
                Size = UDim2.fromOffset(528, 58),
                BackgroundTransparency = 1,
                Parent = root,
        })
        tab.SubRow = row

        build_tab_button(win, tab, #win.Tabs + 1)
        table.insert(win.Tabs, tab)

        function tab:AddSubTab(sub_name, sub_opts)
                sub_opts = sub_opts or {}
                local sub = {}
                sub.Name = tostring(sub_name)
                sub._tab = tab

                local sub_root
                if HAS_CG then
                        sub_root = make("CanvasGroup", {
                                Name = "Sub_" .. sub.Name,
                                Position = UDim2.fromOffset(18, 77),
                                Size = UDim2.fromOffset(540, 395),
                                BackgroundTransparency = 1,
                                GroupTransparency = 0,
                                Visible = false,
                                ClipsDescendants = false,
                                BorderSizePixel = 0,
                                Parent = root,
                        })
                else
                        sub_root = make("Frame", {
                                Name = "Sub_" .. sub.Name,
                                Position = UDim2.fromOffset(18, 77),
                                Size = UDim2.fromOffset(540, 395),
                                BackgroundTransparency = 1,
                                Visible = false,
                                ClipsDescendants = false,
                                BorderSizePixel = 0,
                                Parent = root,
                        })
                end
                sub.Root = sub_root

                local scroll = make("ScrollingFrame", {
                        Name = "Scroll",
                        Size = UDim2.fromOffset(540, 395),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        ScrollBarThickness = 2,
                        ScrollBarImageTransparency = 0.85,
                        CanvasSize = UDim2.fromOffset(0, 0),
                        AutomaticCanvasSize = Enum.AutomaticSize.Y,
                        ScrollingDirection = Enum.ScrollingDirection.Y,
                        ClipsDescendants = true,
                        Parent = sub_root,
                })
                sub.Scroll = scroll

                local left_col, right_col = build_columns(win, scroll)
                sub._left = left_col
                sub._right = right_col
                sub._side = "left"

                build_sub_tab_button(win, tab, sub, #tab.SubTabs + 1, tab.SubRow)
                table.insert(tab.SubTabs, sub)

                function sub:AddGroupbox(title, side)
                        local col = sub._left
                        if side == "right" or side == 2 then
                                col = sub._right
                        end
                        local group = create_groupbox(win, col, tostring(title))
                        return group
                end

                function sub:SetSide(side)
                        sub._side = side == "right" and "right" or "left"
                end

                return sub
        end

        function tab:SetIcon(asset)
                set_icon_display(win, tab.IconHolder, asset, 15, win.Theme.TextPrimary.Color)
        end

        function tab:SetLabel(text)
                tab.Name = tostring(text)
                tab.Text.Text = tab.Name
        end

        if opts.Icon then
                tab:SetIcon(opts.Icon)
        end

        return tab
end

local function serialize_value(el)
        local kind = el.Kind
        if kind == "checkbox" then
                return el:Get() == true
        elseif kind == "slider" then
                return el:Get()
        elseif kind == "combo" then
                return el:Get()
        elseif kind == "multicombo" then
                return el:Get()
        elseif kind == "textbox" then
                return el:Get()
        elseif kind == "colorpicker" then
                local c = el:GetColor()
                return { R = math.floor(c.R * 255 + 0.5), G = math.floor(c.G * 255 + 0.5), B = math.floor(c.B * 255 + 0.5), A = math.floor((el:GetAlpha() or 1) * 255 + 0.5) }
        elseif kind == "keybind" then
                local bind = el.Bind
                local key_name = nil
                if bind.Key then
                        if bind.Key.KeyCode then
                                key_name = bind.Key.KeyCode.Name
                        elseif bind.Key.UserInputType then
                                key_name = bind.Key.UserInputType.Name
                        end
                end
                return { Mode = bind.Mode, Key = key_name }
        elseif kind == "listbox" then
                return el:Get()
        end
        return nil
end

local function apply_serialized(el, data)
        if data == nil then
                return
        end
        local kind = el.Kind
        if kind == "checkbox" then
                el:Set(data == true)
        elseif kind == "slider" then
                el:Set(tonumber(data) or el:Get())
        elseif kind == "combo" then
                el:Set(tostring(data), true)
        elseif kind == "multicombo" then
                if type(data) == "table" then
                        el:Set(data, true)
                end
        elseif kind == "textbox" then
                el:Set(tostring(data), true)
        elseif kind == "colorpicker" then
                if type(data) == "table" then
                        el:SetColor(rgb(data.R or 255, data.G or 255, data.B or 255), (data.A or 255) / 255, true)
                end
        elseif kind == "keybind" then
                if type(data) == "table" then
                        el:SetMode(data.Mode or "Hold")
                        if data.Key then
                                local ok_k, kc = pcall(function()
                                        return Enum.KeyCode[data.Key]
                                end)
                                if ok_k and kc then
                                        el:SetKey({ KeyCode = kc })
                                else
                                        local ok_u, ut = pcall(function()
                                                return Enum.UserInputType[data.Key]
                                        end)
                                        if ok_u and ut then
                                                el:SetKey({ UserInputType = ut })
                                        end
                                end
                        end
                end
        elseif kind == "listbox" then
                el:Set(data)
        end
end

local function config_folder()
        return "airflow"
end

local function config_path(name)
        return "airflow/" .. tostring(name) .. ".json"
end

local function win_save_config(win, name)
        local data = {}
        for flag, el in pairs(win._flag_els) do
                local v = serialize_value(el)
                if v ~= nil then
                        data[flag] = v
                end
        end
        local json = HttpService:JSONEncode(data)
        local wf = type(writefile) == "function" and writefile or nil
        if not wf then
                return false, "writefile not supported"
        end
        local ok = pcall(function()
                if type(isfolder) == "function" and not isfolder(config_folder()) then
                        makefolder(config_folder())
                end
                writefile(config_path(name), json)
        end)
        if ok then
                return true
        end
        return false, "write failed"
end

local function win_load_config(win, name)
        local rf = type(readfile) == "function" and readfile or nil
        local isf = type(isfile) == "function" and isfile or nil
        if not rf then
                return false, "readfile not supported"
        end
        local path = config_path(name)
        if isf and not isf(path) then
                return false, "config not found"
        end
        local ok, json = pcall(rf, path)
        if not ok or not json then
                return false, "read failed"
        end
        local decoded = HttpService:JSONDecode(json)
        for flag, data in pairs(decoded) do
                local el = win._flag_els[flag]
                if el then
                        apply_serialized(el, data)
                end
        end
        return true
end

local function win_get_configs()
        local ld = type(listdir) == "function" and listdir or nil
        if not ld then
                return {}
        end
        local out = {}
        local ok, files = pcall(ld, config_folder())
        if ok and files then
                for _, f in ipairs(files) do
                        local base = string.match(f, "([^/\\]+)$") or f
                        local name = string.match(base, "^(.*)%.json$") or base
                        table.insert(out, name)
                end
        end
        return out
end

local function win_delete_config(name)
        local df = type(delfile) == "function" and delfile or nil
        if not df then
                return false, "delfile not supported"
        end
        local ok = pcall(df, config_path(name))
        return ok
end

local function resolve_toggle_key(v)
        if type(v) == "string" then
                local ok, kc = pcall(function()
                        return Enum.KeyCode[v]
                end)
                if ok then
                        return kc
                end
                return Enum.KeyCode.RightShift
        end
        return v or Enum.KeyCode.RightShift
end

local function assemble_window(win)
        win._flag_els = {}

        win.RefreshKeybindList = function(self)
                refresh_keybind_list(win)
        end

        win._update_watermark_text = function(self)
        end

        win.AddTab = function(self, name, opts)
                return create_tab_object(win, name, opts)
        end

        win.SetTab = function(self, index)
                select_tab(win, index)
        end

        win.GetTab = function(self, index)
                return win.Tabs[index]
        end

        win.GetCurrentTab = function(self)
                return win.Tabs[win.CurrentTab or 0]
        end

        win.Show = function(self)
                fade_window(win, true)
        end

        win.Hide = function(self)
                fade_window(win, false)
        end

        win.Toggle = function(self)
                fade_window(win, not win.Open)
        end

        win.SetVisible = function(self, state)
                fade_window(win, state == true)
        end

        win.IsOpen = function(self)
                return win.Open
        end

        win.SetName = function(self, name)
                win.Name = tostring(name)
                win.Title = win.Name
                win._chrome.TitleLabel.Text = win.Name
                build_watermark(win)
        end

        win.SetTitle = function(self, title)
                self:SetName(title)
        end

        win.SetIcon = function(self, asset)
                win.Icon = asset
                set_icon_display(win, win._icon_holder, asset, 14, win.Theme.Accent)
                build_watermark(win)
        end

        win.RemoveIcon = function(self)
                self:SetIcon("")
        end

        win.SetAccent = function(self, color)
                if color and color.R and color.G and color.B then
                        win.Theme.Accent = color
                elseif type(color) == "table" then
                        win.Theme.Accent = rgb(color[1] or 255, color[2] or 255, color[3] or 255)
                end
                apply_accent(win)
                build_watermark(win)
                build_keybind_list(win)
        end

        win.GetAccent = function(self)
                return win.Theme.Accent
        end

        win.SetTheme = function(self, theme)
                win.Theme = merge_theme(win.Theme, theme)
                apply_theme(win)
                build_watermark(win)
                build_keybind_list(win)
                refresh_keybind_list(win)
        end

        win.GetTheme = function(self)
                local out = {}
                for k, v in pairs(win.Theme) do
                        out[k] = v
                end
                return out
        end

        win.SetFont = function(self, font)
                if font then
                        win.Font = font
                        win._chrome.TitleLabel.Font = font
                        for _, d in ipairs(win.ScreenGui:GetDescendants()) do
                                if d:IsA("TextLabel") or d:IsA("TextBox") or d:IsA("TextButton") then
                                        pcall(function()
                                                d.Font = font
                                        end)
                                end
                        end
                end
        end

        win.GetFont = function(self)
                return win.Font
        end

        win.SetToggleKey = function(self, key)
                win._toggle_key = resolve_toggle_key(key)
        end

        win.GetToggleKey = function(self)
                return win._toggle_key
        end

        win.SetDraggable = function(self, state)
                win._draggable = state ~= false
        end

        win.IsDraggable = function(self)
                return win._draggable
        end

        win.SetBlur = function(self, state)
                set_blur_enabled(win, state == true)
        end

        win.SetWatermark = function(self, cfg)
                if type(cfg) == "boolean" then
                        win.WatermarkEnabled = cfg
                elseif type(cfg) == "table" then
                        win.WatermarkConfig = cfg
                        win.WatermarkEnabled = cfg.Enabled ~= false
                end
                build_watermark(win)
        end

        win.SetKeybindList = function(self, cfg)
                if type(cfg) == "boolean" then
                        win.KeybindsEnabled = cfg
                elseif type(cfg) == "table" then
                        win.KeybindsConfig = cfg
                        win.KeybindsEnabled = cfg.Enabled ~= false
                end
                build_keybind_list(win)
                refresh_keybind_list(win)
        end

        win.Notify = function(self, text, duration)
                notify(win, text, duration)
        end

        win.SaveConfig = function(self, name)
                return win_save_config(win, name)
        end

        win.LoadConfig = function(self, name)
                return win_load_config(win, name)
        end

        win.GetConfigs = function(self)
                return win_get_configs()
        end

        win.DeleteConfig = function(self, name)
                return win_delete_config(name)
        end

        win.Get = function(self, flag)
                local el = win._flag_els[flag]
                if not el then
                        return nil
                end
                return el.Get and el:Get() or el.Value
        end

        win.Set = function(self, flag, value)
                local el = win._flag_els[flag]
                if el and el.Set then
                        el:Set(value)
                end
        end

        win.GetElement = function(self, flag)
                return win._flag_els[flag]
        end

        win.ClosePopups = function(self)
                close_popup(win)
        end

        win.Unload = function(self)
                if win.Destroyed then
                        return
                end
                win.Destroyed = true
                for _, c in ipairs(win._conns) do
                        pcall(function()
                                c:Disconnect()
                        end)
                end
                win._conns = {}
                if win._blur then
                        pcall(function()
                                win._blur:Destroy()
                        end)
                        win._blur = nil
                end
                pcall(function()
                        win.ScreenGui:Destroy()
                end)
                for i, w in ipairs(Airflow.Windows) do
                        if w == win then
                                table.remove(Airflow.Windows, i)
                        end
                end
        end

        win.Destroy = function(self)
                self:Unload()
        end

        table.insert(win._theme_hooks, function()
                build_watermark(win)
                build_keybind_list(win)
        end)

        table.insert(win._conns, UserInputService.InputBegan:Connect(function(input, processed)
                if win.Destroyed then
                        return
                end
                if win._text_focus > 0 then
                        return
                end
                if input.KeyCode and win._toggle_key and input.KeyCode == win._toggle_key then
                        fade_window(win, not win.Open)
                end
        end))
end

function Airflow.CreateWindow(a, b)
        local opts = b or a
        if type(opts) ~= "table" then
                opts = {}
        end
        if G.__AIRFLOW_INITIALIZING then
                task.wait()
        end
        local win, scr, main = build_window(opts)
        assemble_window(win)

        win._toggle_key = resolve_toggle_key(opts.ToggleKey)
        win.WatermarkEnabled = true
        win.KeybindsEnabled = true
        if opts.Watermark == false then
                win.WatermarkEnabled = false
        end
        if opts.KeybindList == false then
                win.KeybindsEnabled = false
        end
        if type(opts.Watermark) == "table" then
                win.WatermarkConfig = opts.Watermark
                if opts.Watermark.Enabled == false then
                        win.WatermarkEnabled = false
                end
        end
        if type(opts.KeybindList) == "table" then
                win.KeybindsConfig = opts.KeybindList
                if opts.KeybindList.Enabled == false then
                        win.KeybindsEnabled = false
                end
        end

        protect_gui(scr)
        build_watermark(win)
        build_keybind_list(win)
        apply_theme(win)
        setup_drag(win)

        if opts.OpenOnStart ~= false then
                fade_window(win, true)
                win.Open = true
        end

        table.insert(Airflow.Windows, win)
        G.__AIRFLOW_LIB = Airflow
        return win
end

G.__AIRFLOW_LIB = Airflow

return Airflow
