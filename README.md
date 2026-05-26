<div align='center'>
  <h1>💫 Exhume Dissector</h1>
  
  *View LocalScripts and ModuleScripts using **Exhume.***
</div>

---

## 🛠️ Usage
Load the **Exhume API** using:
```lua
local Exhume = loadstring(game:HttpGet('https://raw.githubusercontent.com/Phemeti/Exhume/refs/heads/main/ExhumeAPI.lua', true))()
```
---
### ⚙️ Usage Functions
`Exhume:RunDissector` - Dissects the Script, returning a module

`DissectorResults:GetContents()` - Returns the dissected contents

---

### 📝 Example script
```lua
local Exhume = loadstring(game:HttpGet('https://raw.githubusercontent.com/Phemeti/Exhume/refs/heads/main/ExhumeAPI.lua', true))()

local AnimateScript = game.Players.LocalPlayer.Character.Animate
local DissectorResults = Exhume:RunDissector(AnimateScript)

setclipboard(DissectorResults:GetContents()) -- Copies the contents onto clipboard, check clipboard to see the contents.
```

---

> [!NOTE]
> This is a *pretty bad* for viewing scripts, it may **fail to return stuff that may be useful**. And the dissector takes around **4-9 seconds** to finish, depending on the script size.
>
> Also, this will **not work** for low-level executors like **Xeno and Solara**, recommended are **Volt**, **Potassium**, or **Synapse Z** (cheapest)
