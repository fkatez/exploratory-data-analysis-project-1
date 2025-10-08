# Troubleshooting the `title()` option error in the succession risk graphs

The error that appears as something like `title(Succession not found` is caused by
Stata trying to expand a local macro named `title` that is **not wrapped in
quotes**. When the macro is evaluated its value contains spaces (for example,
`Succession risk dot plot`). Because the value is inserted without quotation
marks, Stata sees it as several separate tokens: `Succession`, `risk`, `dot`,
and `plot`. The first token is interpreted as part of the `title()` option, but
Stata then fails to find the closing parenthesis immediately after it and throws
an error that mentions `title(Succession`.

To avoid that parsing problem, always surround macro references in option
arguments with double quotes. For example:

```stata
local gtitle `"Succession risk dot plot"'
graph dot Risk_Index, ///
    over(subspec_label, sort(1) descending) ///
    title(`gtitle')
```

The trailing `///` tokens are the recommended way to continue long commands
across multiple lines in Stata while keeping the code readable.

Here the macro is expanded to `"Succession risk dot plot"`, so Stata receives a
properly quoted string and the graph command runs without an error.

The companion do-file [`notes/succession_risk_analysis.do`](succession_risk_analysis.do)
contains the fully corrected code that applies this quoting pattern to the
succession risk visualisations. Figure 7 is now built with a `twoway` scatter so
each subspecialty dot can inherit a risk-coded colour palette while keeping the
reference lines and descriptive note in place. Figure 8 has been removed per the
latest specification, so the workflow focuses entirely on the colour-coded dot
plot export.
