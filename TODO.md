# TODO

- Print version
- WARN and report subroutines can be merged into one

```
if (s_option('bracket-space-in')) {
	WARN("bracket-space-in",
	    "space prohibited after that open square bracket");
}
```
 could be simplified by removing the `s_option('bracket-space-in')`, and move it in the `WARN` subroutine
