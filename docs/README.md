# IEEE Smart Systems Template

Compile `main.tex` with:

1. pdflatex
2. biber
3. pdflatex
4. pdflatex

In Overleaf: set bibliography tool to Biber if needed.

Toggle page breaks in `main.tex`:

```latex
\chapterpagebreakstrue     % page breaks ON
% \chapterpagebreaksfalse  % page breaks OFF
```

For a wide IEEE figure spanning both columns, use:

```latex
\begin{widefigureenv}{Caption}{fig:label}
    \includegraphics[width=0.95\textwidth]{assets/your-image.png}
\end{widefigureenv}
```
