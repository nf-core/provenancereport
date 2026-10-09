#!/usr/bin/env python3

"""Append a runtime package-version fallback to a Quarto notebook copy."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

import yaml


R_FALLBACK = r'''```{r}
#| label: nf-core-package-versions
#| include: false
if (!file.exists("versions.csv")) {
    packages <- sort(setdiff(loadedNamespaces(), "base"))
    versions <- data.frame(
        package = c("R", packages),
        version = c(
            as.character(getRversion()),
            vapply(packages, function(package) {
                as.character(utils::packageVersion(package))
            }, character(1))
        )
    )
    write.table(
        versions,
        "versions.csv",
        sep = ",",
        row.names = FALSE,
        col.names = FALSE,
        quote = FALSE
    )
}
```'''


PYTHON_FALLBACK = r'''```{python}
#| label: nf-core-package-versions
#| include: false
import sys as _nfcore_sys

_nfcore_loaded_modules = set(_nfcore_sys.modules)

import csv as _nfcore_csv
import importlib.metadata as _nfcore_metadata
import os as _nfcore_os
import platform as _nfcore_platform

if not _nfcore_os.path.exists("versions.csv"):
    _nfcore_package_map = _nfcore_metadata.packages_distributions()
    _nfcore_modules = {
        module.partition(".")[0]
        for module in _nfcore_loaded_modules
        if module
    }
    _nfcore_distributions = sorted({
        distribution
        for module in _nfcore_modules
        for distribution in _nfcore_package_map.get(module, [])
    }, key=str.lower)
    _nfcore_versions = [("python", _nfcore_platform.python_version())]
    for _nfcore_distribution in _nfcore_distributions:
        try:
            _nfcore_versions.append((
                _nfcore_distribution,
                _nfcore_metadata.version(_nfcore_distribution),
            ))
        except _nfcore_metadata.PackageNotFoundError:
            pass
    with open("versions.csv", "w", newline="", encoding="utf-8") as _nfcore_handle:
        _nfcore_csv.writer(_nfcore_handle).writerows(_nfcore_versions)
```'''


class NotebookPreparationError(ValueError):
    """Raised when the notebook execution engine cannot be selected safely."""


def parse_front_matter(content: str) -> dict[str, Any]:
    """Parse only the initial Quarto YAML front matter block."""

    lines = content.splitlines()
    if not lines or lines[0].lstrip("\ufeff").strip() != "---":
        return {}

    closing_index = next(
        (index for index, line in enumerate(lines[1:], start=1) if line.strip() in {"---", "..."}),
        None,
    )
    if closing_index is None:
        raise NotebookPreparationError("YAML front matter is missing its closing delimiter")

    try:
        front_matter = yaml.safe_load("\n".join(lines[1:closing_index]))
    except yaml.YAMLError as error:
        raise NotebookPreparationError(f"YAML front matter is invalid: {error}") from error

    if front_matter is None:
        return {}
    if not isinstance(front_matter, dict):
        raise NotebookPreparationError("YAML front matter must be a mapping")
    return front_matter


def code_cell_languages(content: str) -> set[str]:
    """Return languages declared by executable fenced code cells."""

    pattern = re.compile(r"(?m)^[ \t]*(?:`{3,}|~{3,})\{([A-Za-z][A-Za-z0-9_+-]*)(?:[ ,}])")
    return {match.group(1).lower() for match in pattern.finditer(content)}


def notebook_engine(notebook: Path, content: str) -> str:
    """Select the supported runtime using front matter and code-cell languages."""

    front_matter = parse_front_matter(content)
    languages = code_cell_languages(content)
    has_r_cells = "r" in languages
    has_python_cells = "python" in languages

    if has_r_cells and has_python_cells:
        raise NotebookPreparationError(
            "mixed R and Python code cells are not supported for automatic package-version capture"
        )

    configured_engine = front_matter.get("engine")
    if configured_engine is not None and not isinstance(configured_engine, str):
        raise NotebookPreparationError("the Quarto 'engine' field must be a string")

    configured_engine = configured_engine.lower() if configured_engine else None
    configured_jupyter = front_matter.get("jupyter")
    jupyter_is_configured = configured_jupyter is not None and configured_jupyter is not False

    if configured_engine == "knitr":
        if jupyter_is_configured:
            raise NotebookPreparationError("the notebook configures both knitr and Jupyter")
        if has_python_cells:
            raise NotebookPreparationError("a knitr notebook cannot use Python code cells for automatic capture")
        return "r"

    if configured_engine == "jupyter" or jupyter_is_configured:
        if has_r_cells:
            raise NotebookPreparationError("a Jupyter notebook cannot use R code cells for automatic capture")
        return "python"

    if configured_engine is not None:
        raise NotebookPreparationError(
            f"Quarto engine '{configured_engine}' is not supported for automatic package-version capture"
        )

    if notebook.suffix.lower() == ".rmd":
        if has_python_cells:
            raise NotebookPreparationError("an R Markdown notebook cannot use Python code cells for automatic capture")
        return "r"
    if has_r_cells:
        return "r"
    if has_python_cells:
        return "python"

    raise NotebookPreparationError(
        "could not determine whether the notebook uses R/knitr or Python/Jupyter"
    )


def prepare_notebook(input_path: Path, output_path: Path) -> str:
    """Write a prepared notebook copy and return its selected engine."""

    content = input_path.read_text(encoding="utf-8")
    engine = notebook_engine(input_path, content)
    fallback = R_FALLBACK if engine == "r" else PYTHON_FALLBACK
    separator = "\n" if content.endswith("\n") else "\n\n"
    output_path.write_text(f"{content}{separator}{fallback}\n", encoding="utf-8")
    return engine


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Source .qmd or .Rmd notebook")
    parser.add_argument("--output", required=True, type=Path, help="Prepared notebook copy")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        engine = prepare_notebook(args.input, args.output)
    except (OSError, UnicodeError, NotebookPreparationError) as error:
        print(f"ERROR: Could not prepare '{args.input.name}': {error}", file=sys.stderr)
        return 1

    print(f"Prepared '{args.input.name}' using the {engine} package-version fallback")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
