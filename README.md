# oc-demo

One-shot macOS provisioning for an [opencode](https://opencode.ai) + [OpenRouter](https://openrouter.ai) demo environment.

```bash
./setup-oc-demo.sh --check   # dry run — report only, change nothing
./setup-oc-demo.sh           # ask before replacing anything that exists
```

## What it does

1. Creates `~/projects/oc-demo/{k3,glm,claude,inkling,deepseek}`
2. Installs opencode, or upgrades it when a newer release exists
3. Adds opencode to `PATH` permanently
4. Installs a tuned OpenRouter provider-routing config

Anything **missing** is created without asking. Anything that already **exists and
holds data** is left alone unless you confirm — every prompt defaults to **no**.

## Flags

| Flag | Effect |
|---|---|
| `--check` | Report only; changes nothing |
| `--yes` / `-y` | Unattended: replace existing data (**destructive**) |
| `--no` | Unattended: never replace, only fill gaps |
| `--help` | Usage |

## The routing config

Pins GLM 5.3 and Kimi K3 to fast providers instead of cheap ones:

```jsonc
"provider": {
  "order": ["modal", "baseten", "together"],
  "ignore": ["morph", "phala"],
  "allow_fallbacks": true
}
```

`order` sets the preference sequence; `allow_fallbacks` keeps a provider outage
from becoming a hard failure. `max_tokens` is a runaway guard, not a quality cap.

Measured on the provider tables and live logs that motivated this config:

| Model | Before | After |
|---|---|---|
| GLM 5.3 | Phala, 20–62 tok/s | Modal, 139–399 tok/s |
| Kimi K3 | Morph, 3.5–11 tok/s | Modal, 66–336 tok/s |

Reasoning effort is deliberately left **unset** so opencode and the user decide
per run (`opencode run --variant high|low`). Note GLM 5.3 cannot disable
reasoning and defaults to `max`.

## Notes

- macOS only; the script exits on other platforms.
- Written for stock **bash 3.2** — no bash 4+ syntax.
- **No API key is included.** Run `opencode auth login` on each machine.
- Re-runnable: existing config is compared semantically and backed up with a
  timestamp before any replacement.

## License

MIT
