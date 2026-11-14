# Laptop Check

Inspect a used Windows laptop before buying. Nothing gets installed.

Open **PowerShell** on the laptop and paste:

```powershell
irm https://raw.githubusercontent.com/najiibmohamed11/laptopcheck/main/run.ps1 | iex
```

The script asks for admin access, runs the inspection from a temp folder, opens the report, then deletes everything.
