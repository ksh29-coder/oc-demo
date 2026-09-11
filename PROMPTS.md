# Demo prompts

Nine prompts, run in order in a single session. Each builds on the last.

Run the same sequence per model, one model per folder under `~/projects/oc-demo/`
(`k3`, `glm`, `claude`, `inkling`, `deepseek`), then compare the results.

In prompt 1, replace `[model]` with the model being tested.

---

### 1 — Screener

```
Build a stock screener in a single HTML file. Use S&P 500 stocks — real tickers, names and sectors — with realistic mock values for market cap, P/E, dividend yield, 1yr return and beta. Show it in a sortable table. Label the page as built by [model].
```

### 2 — Filters

```
Add filters above the table — sector, market cap, P/E, dividend yield and beta. Update the table live and show how many stocks match.
```

### 3 — Detail drawer

```
Let me click a stock to open a detail panel from the right — company description, recent earnings, and a share price chart. Backfill any data needed.
```

### 4 — Compare

```
Let me select two stocks and compare them side by side, with the differences highlighted.
```

### 5 — Risk/return scatter

```
Add a scatter chart of beta against 1yr return, coloured by sector, with tickers on hover. Split it into four labelled quadrants.
```

### 6 — Portfolio

```
Build a portfolio from the currently filtered stocks. Equal or market cap weighted, with a max position cap. Let me override the weight on any individual stock. Show a treemap by sector and a holdings table.
```

### 7 — Exposures

```
Show the portfolio's overall exposures — sector breakdown, average P/E, yield and beta versus the market.
```

### 8 — Active weight

```
Show active weight against the index, per position and per sector. Backfill any data needed.
```

### 9 — Trade list

```
Change my portfolio and show a trade list to get there — buys and sells with share counts and dollar values.
```
