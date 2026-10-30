# Memory Optimizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lightweight Windows memory optimizer with a cyan acrylic UI, persistent settings, memory automation, registry cleanup, process control, startup management, and a single-EXE packaging path.

**Architecture:** A small Python application separates persistence, Windows maintenance operations, and Tkinter UI. A background monitor polls memory and only triggers safe memory cleanup; registry/process/startup actions remain explicit manual actions with confirmations. Settings live in `%APPDATA%\\NovaMemory\\settings.json`.

**Tech Stack:** Python 3, Tkinter, psutil, ctypes/winreg, PyInstaller, unittest.

---

### Task 1: Add tested persistence and maintenance primitives

**Files:**
- Create: `app/settings.py`
- Create: `app/maintenance.py`
- Create: `tests/test_settings.py`

- [x] Write tests for defaults, clamped threshold, and JSON round-trip.
- [x] Implement settings storage and Windows-safe maintenance functions.
- [x] Run `python -m unittest discover -s tests -v`.

### Task 2: Build the desktop UI

**Files:**
- Create: `app/main.py`
- Create: `app/__init__.py`

- [x] Add the acrylic-style main window, memory meter, optimize action, settings slider, maintenance tabs, and status messages.
- [x] Add live display refresh and 5-second automatic monitor with a 60-second cooldown.
- [x] Connect registry preview/backup/confirmation, process scope selection, and startup safe/full management.

### Task 3: Package and verify

**Files:**
- Create: `requirements.txt`
- Create: `build.ps1`
- Create: `README.md`

- [x] Add the minimal dependency and PyInstaller build command.
- [x] Run unit tests, compile checks, and a headless UI startup check.
- [x] Run the EXE build and verify the output starts successfully.
