
Edited here: https://www.codecogs.com/latex/eqneditor.php

```latex
\\
min_r \in \mathbb{Z}_\geq_0 \\
max_r \in \mathbb{Z}_>_0, max_r \geq min_r \\
indexed_r \in \mathbb{Z}_>_0, indexed_r \leq max_r \\
\\
hcpmin(clone_x) =
\begin{cases}
1 & x < min(min_r, indexed_r) - 1 \\
min_r - x & x = min(min_r, indexed_r) - 1 \\
0 & otherwise
\end{cases}\\
x \in [0, indexed_r - 1]\\
\\
hcpmax(clone_x)=
\begin{cases}
1 & x < indexed_r - 1 \\
max_r - x & x = indexed_r - 1
\end{cases}\\
x \in [0, indexed_r-1]\\
```
