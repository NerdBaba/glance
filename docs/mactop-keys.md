# Mactop Widget Keys Reference

This document describes the exact mactop JSON keys used by Glance widgets.

## Temperature Widget

- **Path:** `temperatures[]`
- **Filter:** Groups "CPU E-Core", "CPU P-Core", "CPU Die"
- **Key:** `avg_celsius` - temperature in Celsius
- **Display:** Average of the 3 groups

## Fan Widget

- **Path:** `fans[]`
- **Key:** `rpm` - fan speed in RPM

## Energy Widget

- **Path:** `soc_metrics`
- **Keys:**
  - `total_power` - total system power in Watts (includes all components)
  - `system_power` - system power in Watts
  - `cpu_power` - CPU power in Watts
  - `gpu_power` - GPU power in Watts
  - `dram_power` - Memory power in Watts
  - `ane_power` - Neural Engine power in Watts

## Configuration

```toml
[widgets.default.energy]
mode = "current"  # or "total" for accumulated energy in kWh
```

## Example Output

```json
{
  "soc_metrics": {
    "cpu_power": 0.203,
    "gpu_power": 0.237,
    "ane_power": 0,
    "dram_power": 0.152,
    "gpu_sram_power": 0.005,
    "system_power": 8.37,
    "total_power": 8.96
  },
  "temperatures": [
    {"group": "CPU E-Core", "avg_celsius": 49.4},
    {"group": "CPU P-Core", "avg_celsius": 49.5},
    {"group": "CPU Die", "avg_celsius": 55.6}
  ],
  "fans": [
    {"id": 0, "name": "Fan 0", "rpm": 1010}
  ]
}
```