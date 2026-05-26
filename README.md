<div align='center'>
  <h1>💫 Exhume Dissector</h1>
  
  *View LocalScripts and ModuleScripts using **Exhume.***
</div>

---

## 🛠️ Usage
Load the **Exhume API** using:
```lua
local Exhume = game:HttpGet('https://raw.githubusercontent.com/Phemeti/Exhume/refs/heads/main/ExhumeAPI.lua', true))()
```
---
### ⚙️ Usage Functions
`Exhume:RunDissector` - Dissects the Script, returning a module

`DissectorResults:GetContents()` - Returns the dissected contents

---

### 📝 Example script
```lua
local Exhume = game:HttpGet('https://raw.githubusercontent.com/Phemeti/Exhume/refs/heads/main/ExhumeAPI.lua', true))()

local AnimateScript = game.Players.LocalPlayer.Character.Animate
local DissectorResults = Exhume:RunDissector(target)

setclipboard(DissectorResults:GetContents())
```

---

> [!NOTE]
> This is a pretty bad for viewing scripts, it may fail to return stuff that may be useful. And the dissector takes around 4-9 seconds to finish, depending on the script size.
