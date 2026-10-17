import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import json
import serial
import serial.tools.list_ports
import time

class SpriteStudioPro(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("👾 Retro FPGA Sprite Studio PRO - Tang Nano 20K Edition")
        self.geometry("1120x740")
        self.configure(bg="#181825")
        self.resizable(False, False)

        # BBC BASIC 8-color palette (0 = Transparant)
        self.colors = {
            0: ("0: Transparant", "#2b2b3b", "#ffffff"),
            1: ("1: Rood",        "#ff2a2a", "#ffffff"),
            2: ("2: Groen",       "#00e600", "#000000"),
            3: ("3: Geel",        "#ffe600", "#000000"),
            4: ("4: Blauw",       "#2a6aff", "#ffffff"),
            5: ("5: Magenta",     "#ff2aff", "#000000"),
            6: ("6: Cyaan",       "#00ffff", "#000000"),
            7: ("7: Wit",         "#ffffff", "#000000")
        }

        self.current_color = 3  # Start met Geel
        self.current_tool = "pen"  # pen, bucket, picker
        self.show_grid = True
        self.grid_data = [[0 for _ in range(16)] for _ in range(16)]
        self.undo_stack = []
        self.ser = None

        self.presets = self.get_presets()
        self.setup_ui()
        self.refresh_canvas()

    def get_presets(self):
        return {
            "Smiley": [
                [0,0,0,0,3,3,3,3,3,3,3,3,0,0,0,0],
                [0,0,3,3,3,3,3,3,3,3,3,3,3,3,0,0],
                [0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0],
                [0,3,3,3,4,4,3,3,3,3,4,4,3,3,3,0],
                [3,3,3,3,4,4,3,3,3,3,4,4,3,3,3,3],
                [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
                [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
                [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
                [3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],
                [3,3,1,3,3,3,3,3,3,3,3,3,3,1,3,3],
                [0,3,1,1,3,3,3,3,3,3,3,3,1,1,3,0],
                [0,3,3,1,1,1,1,1,1,1,1,1,1,3,3,0],
                [0,0,3,3,3,1,1,1,1,1,1,3,3,3,0,0],
                [0,0,0,0,3,3,3,3,3,3,3,3,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            ],
            "Koe": [
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,7,7,7,7,0,0,0,0,0,0],
                [0,0,0,0,0,7,1,7,7,1,7,7,0,0,0,0],
                [0,0,7,7,7,7,7,7,0,0,7,7,7,0,0,0],
                [0,7,7,0,0,7,7,0,0,7,7,7,7,7,0,0],
                [0,7,7,7,7,7,7,7,7,7,7,5,5,5,0,0],
                [0,0,7,7,0,0,7,7,7,7,7,5,0,5,0,0],
                [0,0,7,7,7,7,7,0,0,7,7,5,5,5,0,0],
                [0,0,7,0,0,7,7,7,7,7,0,0,0,0,0,0],
                [0,0,7,0,0,7,0,0,0,7,0,0,0,0,0,0],
                [0,0,7,0,0,7,0,0,0,7,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            ],
            "Schuur": [
                [0,0,0,0,0,0,0,7,7,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,7,1,1,7,0,0,0,0,0,0],
                [0,0,0,0,0,7,1,1,1,1,7,0,0,0,0,0],
                [0,0,0,0,7,1,1,3,3,1,1,7,0,0,0,0],
                [0,0,0,7,1,1,1,3,3,1,1,1,7,0,0,0],
                [0,0,7,7,7,7,7,7,7,7,7,7,7,7,0,0],
                [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
                [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
                [0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0],
                [0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0],
                [0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0],
                [0,0,1,1,1,0,0,7,7,0,0,1,1,1,0,0],
                [0,0,1,1,1,0,0,7,7,0,0,1,1,1,0,0],
                [0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0],
                [0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0],
                [0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0]
            ],
            "Boom": [
                [0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0],
                [0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0],
                [0,0,0,0,2,2,1,2,2,2,2,2,0,0,0,0],
                [0,0,0,2,2,2,2,2,2,1,2,2,2,0,0,0],
                [0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0],
                [0,0,2,2,1,2,2,2,2,2,2,1,2,2,0,0],
                [0,0,0,2,2,2,2,2,2,2,2,2,2,0,0,0],
                [0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0],
                [0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0]
            ],
            "Space Invader": [
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,2,0,0,0,0,0,0,0,2,0,0,0,0],
                [0,0,0,0,2,0,0,0,0,0,2,0,0,0,0,0],
                [0,0,0,2,2,2,2,2,2,2,2,2,0,0,0,0],
                [0,0,2,2,0,2,2,2,2,2,0,2,2,0,0,0],
                [0,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0],
                [0,2,0,2,2,2,2,2,2,2,2,2,0,2,0,0],
                [0,2,0,2,0,0,0,0,0,0,0,2,0,2,0,0],
                [0,0,0,0,2,2,0,0,0,2,2,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
                [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            ]
        }

    def setup_ui(self):
        # Top Header
        header = tk.Frame(self, bg="#11111b", height=45)
        header.pack(fill=tk.X)
        tk.Label(
            header, text="⚡ RETRO FPGA SPRITE STUDIO PRO ⚡",
            font=("Consolas", 15, "bold"), bg="#11111b", fg="#cba6f7"
        ).pack(side=tk.LEFT, padx=15, pady=8)

        self.lbl_status = tk.Label(
            header, text="Klaar om te tekenen! (Linkermuis = Teken, Rechtermuis = Gum)",
            font=("Consolas", 10), bg="#11111b", fg="#a6e3a1"
        )
        self.lbl_status.pack(side=tk.RIGHT, padx=15)

        # Main Body Frame
        main_frame = tk.Frame(self, bg="#181825")
        main_frame.pack(fill=tk.BOTH, expand=True, padx=15, pady=10)

        # ================= LEFT PANEL: CANVAS =================
        left_panel = tk.Frame(main_frame, bg="#1e1e2e", bd=2, relief=tk.RIDGE)
        left_panel.pack(side=tk.LEFT, padx=5, fill=tk.Y)

        self.cell_size = 28
        canvas_dim = 16 * self.cell_size
        self.canvas = tk.Canvas(
            left_panel, width=canvas_dim, height=canvas_dim,
            bg="#2b2b3b", highlightthickness=0, cursor="tcross"
        )
        self.canvas.pack(padx=12, pady=12)

        self.canvas.bind("<Button-1>", self.on_left_click)
        self.canvas.bind("<B1-Motion>", self.on_left_drag)
        self.canvas.bind("<Button-3>", self.on_right_click)
        self.canvas.bind("<B3-Motion>", self.on_right_drag)
        self.canvas.bind("<Motion>", self.on_mouse_move)

        self.rects = [[None for _ in range(16)] for _ in range(16)]
        for y in range(16):
            for x in range(16):
                x1, y1 = x * self.cell_size, y * self.cell_size
                x2, y2 = x1 + self.cell_size, y1 + self.cell_size
                self.rects[y][x] = self.canvas.create_rectangle(
                    x1, y1, x2, y2, fill="#2b2b3b", outline="#45475a"
                )

        # Bottom Canvas Info bar
        canvas_bar = tk.Frame(left_panel, bg="#1e1e2e")
        canvas_bar.pack(fill=tk.X, padx=12, pady=(0, 10))

        self.lbl_coords = tk.Label(
            canvas_bar, text="Pos: (0, 0) | Index: 0",
            font=("Consolas", 10, "bold"), bg="#1e1e2e", fg="#89b4fa"
        )
        self.lbl_coords.pack(side=tk.LEFT)

        tk.Button(
            canvas_bar, text="🌐 Raster Aan/Uit", font=("Consolas", 9, "bold"),
            bg="#313244", fg="#cdd6f4", activebackground="#45475a",
            command=self.toggle_grid, relief=tk.FLAT, padx=6
        ).pack(side=tk.RIGHT)

        # ================= MIDDLE PANEL: TOOLS & PALETTE =================
        mid_panel = tk.Frame(main_frame, bg="#1e1e2e", bd=2, relief=tk.RIDGE, width=280)
        mid_panel.pack(side=tk.LEFT, padx=10, fill=tk.Y)

        # 1. Kleurenpalet
        tk.Label(
            mid_panel, text="🎨 BBC BASIC PALET",
            font=("Consolas", 11, "bold"), bg="#1e1e2e", fg="#f9e2af"
        ).pack(pady=(10, 5))

        self.palette_btns = {}
        pal_frame = tk.Frame(mid_panel, bg="#1e1e2e")
        pal_frame.pack(padx=10, fill=tk.X)

        for col_idx, (name, hex_bg, hex_fg) in self.colors.items():
            btn = tk.Button(
                pal_frame, text=name, font=("Consolas", 10, "bold"),
                bg=hex_bg, fg=hex_fg, activebackground=hex_bg, activeforeground=hex_fg,
                relief=tk.RAISED, bd=3, width=22,
                command=lambda c=col_idx: self.select_color(c)
            )
            btn.pack(pady=2)
            self.palette_btns[col_idx] = btn
        self.select_color(3)

        # 2. Gereedschap (Tools)
        tk.Label(
            mid_panel, text="🛠️ GEREEDSCHAP",
            font=("Consolas", 11, "bold"), bg="#1e1e2e", fg="#f9e2af"
        ).pack(pady=(12, 4))

        tool_frame = tk.Frame(mid_panel, bg="#1e1e2e")
        tool_frame.pack(padx=10, fill=tk.X)

        self.tool_btns = {}
        tools = [
            ("pen", "✏️ Potlood"),
            ("bucket", "🪣 Vulemmer"),
            ("picker", "💉 Pipet")
        ]
        for t_id, t_label in tools:
            b = tk.Button(
                tool_frame, text=t_label, font=("Consolas", 9, "bold"),
                bg="#313244", fg="#cdd6f4", width=9, relief=tk.FLAT,
                command=lambda tid=t_id: self.select_tool(tid)
            )
            b.pack(side=tk.LEFT, padx=2, pady=2)
            self.tool_btns[t_id] = b
        self.select_tool("pen")

        # 3. Transformaties & Acties
        tk.Label(
            mid_panel, text="🔄 TRANSFORMATIES",
            font=("Consolas", 11, "bold"), bg="#1e1e2e", fg="#f9e2af"
        ).pack(pady=(12, 4))

        trans_frame = tk.Frame(mid_panel, bg="#1e1e2e")
        trans_frame.pack(padx=10)

        btn_cfg = {"font": ("Consolas", 9, "bold"), "bg": "#313244", "fg": "#cdd6f4", "width": 12, "relief": tk.FLAT, "pady": 3}

        tk.Button(trans_frame, text="⬅️ Schuif L", command=lambda: self.shift(-1, 0), **btn_cfg).grid(row=0, column=0, padx=2, pady=2)
        tk.Button(trans_frame, text="➡️ Schuif R", command=lambda: self.shift(1, 0), **btn_cfg).grid(row=0, column=1, padx=2, pady=2)
        tk.Button(trans_frame, text="⬆️ Schuif Op", command=lambda: self.shift(0, -1), **btn_cfg).grid(row=1, column=0, padx=2, pady=2)
        tk.Button(trans_frame, text="⬇️ Schuif Neer", command=lambda: self.shift(0, 1), **btn_cfg).grid(row=1, column=1, padx=2, pady=2)
        tk.Button(trans_frame, text="↔️ Spiegel H", command=self.flip_h, **btn_cfg).grid(row=2, column=0, padx=2, pady=2)
        tk.Button(trans_frame, text="↕️ Spiegel V", command=self.flip_v, **btn_cfg).grid(row=2, column=1, padx=2, pady=2)
        tk.Button(trans_frame, text="🔁 Roteer 90°", command=self.rotate_90, **btn_cfg).grid(row=3, column=0, padx=2, pady=2)
        tk.Button(trans_frame, text="↩️ Undo", command=self.undo, **btn_cfg).grid(row=3, column=1, padx=2, pady=2)

        # 4. Presets & Wissen
        tk.Label(
            mid_panel, text="📦 PRESETS & BESTAND",
            font=("Consolas", 11, "bold"), bg="#1e1e2e", fg="#f9e2af"
        ).pack(pady=(12, 4))

        preset_frame = tk.Frame(mid_panel, bg="#1e1e2e")
        preset_frame.pack(padx=10, fill=tk.X)

        self.combo_preset = ttk.Combobox(preset_frame, values=list(self.presets.keys()), state="readonly", font=("Consolas", 9), width=14)
        self.combo_preset.set("Smiley")
        self.combo_preset.pack(side=tk.LEFT, padx=2)

        tk.Button(
            preset_frame, text="Laad Preset", font=("Consolas", 9, "bold"),
            bg="#89b4fa", fg="#11111b", relief=tk.FLAT, command=self.load_selected_preset
        ).pack(side=tk.LEFT, padx=4)

        file_frame = tk.Frame(mid_panel, bg="#1e1e2e")
        file_frame.pack(padx=10, pady=6, fill=tk.X)

        tk.Button(file_frame, text="💾 Opslaan", font=("Consolas", 9, "bold"), bg="#a6e3a1", fg="#11111b", width=8, relief=tk.FLAT, command=self.save_json).pack(side=tk.LEFT, padx=2)
        tk.Button(file_frame, text="📂 Openen", font=("Consolas", 9, "bold"), bg="#f9e2af", fg="#11111b", width=8, relief=tk.FLAT, command=self.load_json).pack(side=tk.LEFT, padx=2)
        tk.Button(file_frame, text="🗑️ Wis", font=("Consolas", 9, "bold"), bg="#f38ba8", fg="#11111b", width=7, relief=tk.FLAT, command=self.clear_grid).pack(side=tk.LEFT, padx=2)

        # ================= RIGHT PANEL: PREVIEW, FPGA LIVE & BASIC CODE =================
        right_panel = tk.Frame(main_frame, bg="#1e1e2e", bd=2, relief=tk.RIDGE)
        right_panel.pack(side=tk.LEFT, padx=5, fill=tk.BOTH, expand=True)

        # 1. Live Previews (1x en 2x)
        prev_frame = tk.Frame(right_panel, bg="#1e1e2e")
        prev_frame.pack(fill=tk.X, padx=12, pady=10)

        tk.Label(
            prev_frame, text="👁️ PREVIEW:",
            font=("Consolas", 11, "bold"), bg="#1e1e2e", fg="#f9e2af"
        ).pack(side=tk.LEFT, padx=(0, 10))

        self.preview_2x = tk.Canvas(prev_frame, width=32, height=32, bg="#000000", highlightthickness=1, highlightbackground="#585b70")
        self.preview_2x.pack(side=tk.LEFT, padx=5)
        tk.Label(prev_frame, text="(2x)", font=("Consolas", 8), bg="#1e1e2e", fg="#a6adc8").pack(side=tk.LEFT)

        self.preview_4x = tk.Canvas(prev_frame, width=64, height=64, bg="#000000", highlightthickness=1, highlightbackground="#585b70")
        self.preview_4x.pack(side=tk.LEFT, padx=(15, 5))
        tk.Label(prev_frame, text="(4x)", font=("Consolas", 8), bg="#1e1e2e", fg="#a6adc8").pack(side=tk.LEFT)

        # 2. Directe FPGA Upload (Serial)
        fpga_frame = tk.LabelFrame(
            right_panel, text=" 🚀 LIVE TESTEN OP FPGA (OPTIONEEL) ",
            font=("Consolas", 10, "bold"), bg="#1e1e2e", fg="#89dceb", bd=1, relief=tk.SOLID
        )
        fpga_frame.pack(fill=tk.X, padx=12, pady=5)

        row1 = tk.Frame(fpga_frame, bg="#1e1e2e")
        row1.pack(fill=tk.X, padx=8, pady=4)

        tk.Label(row1, text="Poort:", font=("Consolas", 9), bg="#1e1e2e", fg="#cdd6f4").pack(side=tk.LEFT)
        self.combo_port = ttk.Combobox(row1, values=self.get_com_ports(), width=8, font=("Consolas", 9))
        if self.combo_port["values"]:
            self.combo_port.current(0)
        self.combo_port.pack(side=tk.LEFT, padx=4)

        tk.Button(row1, text="🔄", font=("Consolas", 8), bg="#313244", fg="#cdd6f4", relief=tk.FLAT, command=self.refresh_ports).pack(side=tk.LEFT, padx=2)

        tk.Label(row1, text="Sprite ID:", font=("Consolas", 9), bg="#1e1e2e", fg="#cdd6f4").pack(side=tk.LEFT, padx=(8, 2))
        self.spin_sprite_id = tk.Spinbox(row1, from_=0, to=15, width=3, font=("Consolas", 9, "bold"))
        self.spin_sprite_id.pack(side=tk.LEFT, padx=2)

        row2 = tk.Frame(fpga_frame, bg="#1e1e2e")
        row2.pack(fill=tk.X, padx=8, pady=4)

        tk.Label(row2, text="Pos X:", font=("Consolas", 9), bg="#1e1e2e", fg="#cdd6f4").pack(side=tk.LEFT)
        self.entry_x = tk.Entry(row2, width=5, font=("Consolas", 9))
        self.entry_x.insert(0, "640")
        self.entry_x.pack(side=tk.LEFT, padx=4)

        tk.Label(row2, text="Y:", font=("Consolas", 9), bg="#1e1e2e", fg="#cdd6f4").pack(side=tk.LEFT)
        self.entry_y = tk.Entry(row2, width=5, font=("Consolas", 9))
        self.entry_y.insert(0, "512")
        self.entry_y.pack(side=tk.LEFT, padx=4)

        tk.Button(
            row2, text="⚡ Zend naar FPGA!", font=("Consolas", 9, "bold"),
            bg="#cba6f7", fg="#11111b", relief=tk.FLAT, padx=8,
            command=self.send_to_fpga
        ).pack(side=tk.RIGHT)

        # 3. BBC BASIC Code Generator
        code_header = tk.Frame(right_panel, bg="#1e1e2e")
        code_header.pack(fill=tk.X, padx=12, pady=(10, 2))

        tk.Label(
            code_header, text="📜 BBC BASIC CODE GENERATOR",
            font=("Consolas", 11, "bold"), bg="#1e1e2e", fg="#f9e2af"
        ).pack(side=tk.LEFT)

        opt_frame = tk.Frame(right_panel, bg="#1e1e2e")
        opt_frame.pack(fill=tk.X, padx=12, pady=2)

        tk.Label(opt_frame, text="Start Regel:", font=("Consolas", 9), bg="#1e1e2e", fg="#cdd6f4").pack(side=tk.LEFT)
        self.entry_line = tk.Entry(opt_frame, width=6, font=("Consolas", 9, "bold"))
        self.entry_line.insert(0, "1000")
        self.entry_line.pack(side=tk.LEFT, padx=5)

        self.include_loader = tk.BooleanVar(value=True)
        tk.Checkbutton(
            opt_frame, text="Inclusief inlaad-loop (READ/PLOT)",
            variable=self.include_loader, bg="#1e1e2e", fg="#cdd6f4",
            selectcolor="#313244", activebackground="#1e1e2e", activeforeground="#cdd6f4",
            font=("Consolas", 9), command=self.generate_basic_code
        ).pack(side=tk.LEFT, padx=5)

        btn_code_frame = tk.Frame(right_panel, bg="#1e1e2e")
        btn_code_frame.pack(fill=tk.X, padx=12, pady=4)

        tk.Button(
            btn_code_frame, text="🔄 Genereer Code", font=("Consolas", 9, "bold"),
            bg="#89b4fa", fg="#11111b", relief=tk.FLAT, padx=8,
            command=self.generate_basic_code
        ).pack(side=tk.LEFT, padx=(0, 5))

        tk.Button(
            btn_code_frame, text="📋 Kopieer naar Klembord", font=("Consolas", 9, "bold"),
            bg="#a6e3a1", fg="#11111b", relief=tk.FLAT, padx=8,
            command=self.copy_to_clipboard
        ).pack(side=tk.LEFT)

        self.text_out = tk.Text(
            right_panel, width=42, height=18,
            font=("Consolas", 9), bg="#11111b", fg="#a6e3a1",
            insertbackground="#ffffff", relief=tk.FLAT, padx=8, pady=8
        )
        self.text_out.pack(fill=tk.BOTH, expand=True, padx=12, pady=(2, 12))

    # ================= LOGICA & TOOLS =================
    def save_undo(self):
        snapshot = [row[:] for row in self.grid_data]
        if not self.undo_stack or self.undo_stack[-1] != snapshot:
            self.undo_stack.append(snapshot)
            if len(self.undo_stack) > 30:
                self.undo_stack.pop(0)

    def undo(self):
        if self.undo_stack:
            self.grid_data = self.undo_stack.pop()
            self.refresh_canvas()
            self.lbl_status.config(text="Laatste actie ongedaan gemaakt (Undo).")

    def select_color(self, col_idx):
        self.current_color = col_idx
        for idx, btn in self.palette_btns.items():
            if idx == col_idx:
                btn.config(relief=tk.SUNKEN, bd=4, text=f"▶ {self.colors[idx][0]} ◀")
            else:
                btn.config(relief=tk.RAISED, bd=2, text=self.colors[idx][0])

    def select_tool(self, tool_id):
        self.current_tool = tool_id
        for tid, btn in self.tool_btns.items():
            if tid == tool_id:
                btn.config(bg="#cba6f7", fg="#11111b")
            else:
                btn.config(bg="#313244", fg="#cdd6f4")

    def on_mouse_move(self, event):
        x, y = event.x // self.cell_size, event.y // self.cell_size
        if 0 <= x < 16 and 0 <= y < 16:
            idx = y * 16 + x
            self.lbl_coords.config(text=f"Pos: ({x:2d}, {y:2d}) | Pixel Index: {idx:3d}")

    def on_left_click(self, event):
        x, y = event.x // self.cell_size, event.y // self.cell_size
        if not (0 <= x < 16 and 0 <= y < 16):
            return
        if self.current_tool == "picker":
            picked = self.grid_data[y][x]
            self.select_color(picked)
            self.select_tool("pen")
            self.lbl_status.config(text=f"Kleur {picked} opgepikt met pipet!")
            return

        self.save_undo()
        if self.current_tool == "bucket":
            target_col = self.grid_data[y][x]
            self.flood_fill(x, y, target_col, self.current_color)
            self.refresh_canvas()
        else:
            self.paint_cell(x, y, self.current_color)

    def on_left_drag(self, event):
        if self.current_tool == "pen":
            x, y = event.x // self.cell_size, event.y // self.cell_size
            if 0 <= x < 16 and 0 <= y < 16:
                self.paint_cell(x, y, self.current_color)

    def on_right_click(self, event):
        self.save_undo()
        x, y = event.x // self.cell_size, event.y // self.cell_size
        if 0 <= x < 16 and 0 <= y < 16:
            self.paint_cell(x, y, 0)

    def on_right_drag(self, event):
        x, y = event.x // self.cell_size, event.y // self.cell_size
        if 0 <= x < 16 and 0 <= y < 16:
            self.paint_cell(x, y, 0)

    def paint_cell(self, x, y, col_val):
        if self.grid_data[y][x] != col_val:
            self.grid_data[y][x] = col_val
            hex_bg = self.colors[col_val][1]
            self.canvas.itemconfig(self.rects[y][x], fill=hex_bg)
            self.update_previews()
            self.generate_basic_code()

    def flood_fill(self, x, y, target_col, replacement_col):
        if target_col == replacement_col:
            return
        stack = [(x, y)]
        while stack:
            cx, cy = stack.pop()
            if 0 <= cx < 16 and 0 <= cy < 16 and self.grid_data[cy][cx] == target_col:
                self.grid_data[cy][cx] = replacement_col
                stack.extend([(cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)])

    def toggle_grid(self):
        self.show_grid = not self.show_grid
        outline_col = "#45475a" if self.show_grid else ""
        for y in range(16):
            for x in range(16):
                self.canvas.itemconfig(self.rects[y][x], outline=outline_col)

    def refresh_canvas(self):
        for y in range(16):
            for x in range(16):
                col_val = self.grid_data[y][x]
                hex_bg = self.colors[col_val][1]
                self.canvas.itemconfig(self.rects[y][x], fill=hex_bg)
        self.update_previews()
        self.generate_basic_code()

    def update_previews(self):
        self.preview_2x.delete("all")
        self.preview_4x.delete("all")
        for y in range(16):
            for x in range(16):
                c = self.grid_data[y][x]
                if c != 0:
                    hex_c = self.colors[c][1]
                    self.preview_2x.create_rectangle(x*2, y*2, x*2+2, y*2+2, fill=hex_c, outline="")
                    self.preview_4x.create_rectangle(x*4, y*4, x*4+4, y*4+4, fill=hex_c, outline="")

    # ================= TRANSFORMATIES =================
    def shift(self, dx, dy):
        self.save_undo()
        new_grid = [[0 for _ in range(16)] for _ in range(16)]
        for y in range(16):
            for x in range(16):
                nx = (x + dx) % 16
                ny = (y + dy) % 16
                new_grid[ny][nx] = self.grid_data[y][x]
        self.grid_data = new_grid
        self.refresh_canvas()

    def flip_h(self):
        self.save_undo()
        self.grid_data = [row[::-1] for row in self.grid_data]
        self.refresh_canvas()

    def flip_v(self):
        self.save_undo()
        self.grid_data = self.grid_data[::-1]
        self.refresh_canvas()

    def rotate_90(self):
        self.save_undo()
        self.grid_data = [list(row) for row in zip(*self.grid_data[::-1])]
        self.refresh_canvas()

    def clear_grid(self):
        if messagebox.askyesno("Raster Wissen", "Wil je het hele 16x16 veld leegmaken?"):
            self.save_undo()
            self.grid_data = [[0 for _ in range(16)] for _ in range(16)]
            self.refresh_canvas()

    def load_selected_preset(self):
        name = self.combo_preset.get()
        if name in self.presets:
            self.save_undo()
            self.grid_data = [row[:] for row in self.presets[name]]
            self.refresh_canvas()
            self.lbl_status.config(text=f"Preset '{name}' geladen!")

    # ================= BESTANDSBEHEER =================
    def save_json(self):
        filepath = filedialog.asksaveasfilename(
            title="Sla Sprite op", defaultextension=".json",
            filetypes=[("Sprite JSON", "*.json"), ("Alle bestanden", "*.*")]
        )
        if filepath:
            with open(filepath, "w") as f:
                json.dump(self.grid_data, f)
            self.lbl_status.config(text=f"Sprite opgeslagen: {filepath}")

    def load_json(self):
        filepath = filedialog.askopenfilename(
            title="Open Sprite", filetypes=[("Sprite JSON", "*.json"), ("Alle bestanden", "*.*")]
        )
        if filepath:
            try:
                with open(filepath, "r") as f:
                    data = json.load(f)
                if len(data) == 16 and len(data[0]) == 16:
                    self.save_undo()
                    self.grid_data = data
                    self.refresh_canvas()
                    self.lbl_status.config(text=f"Sprite geladen: {filepath}")
                else:
                    messagebox.showerror("Fout", "Ongeldig 16x16 sprite formaat.")
            except Exception as e:
                messagebox.showerror("Fout bij openen", str(e))

    # ================= CODE GENERATIE =================
    def generate_basic_code(self):
        try:
            start_line = int(self.entry_line.get())
        except ValueError:
            start_line = 1000

        try:
            sp_id = int(self.spin_sprite_id.get())
            sx = int(self.entry_x.get())
            sy = int(self.entry_y.get())
        except ValueError:
            sp_id, sx, sy = 0, 640, 512

        lines = []
        if self.include_loader.get():
            lines.append(f"10 REM Laad Sprite in Slot {sp_id} (Zonder DIM array!)")
            lines.append(f"20 RESTORE {start_line}")
            lines.append(f"30 PLOT 200, {sp_id}, 0")
            lines.append(f"40 FOR I=0 TO 255: READ P: PLOT 203, I, P: NEXT I")
            lines.append(f"50 PLOT 201, {sx}, {sy}")

        line_num = start_line
        for row in self.grid_data:
            lines.append(f"{line_num} DATA " + ",".join(map(str, row)))
            line_num += 10

        self.text_out.delete(1.0, tk.END)
        self.text_out.insert(tk.END, "\n".join(lines))

    def copy_to_clipboard(self):
        code = self.text_out.get(1.0, tk.END).strip()
        self.clipboard_clear()
        self.clipboard_append(code)
        self.lbl_status.config(text="📋 BBC BASIC code gekopieerd naar klembord!")

    # ================= LIVE FPGA UPLOAD =================
    def get_com_ports(self):
        return [p.device for p in serial.tools.list_ports.comports()]

    def refresh_ports(self):
        ports = self.get_com_ports()
        self.combo_port["values"] = ports
        if ports:
            self.combo_port.current(0)

    def send_to_fpga(self):
        port = self.combo_port.get()
        if not port:
            messagebox.showwarning("Geen COM-poort", "Selecteer eerst de COM-poort van je Tang Nano 20K!\n(Sluit eventueel eerst minigpu_control.py als die de poort bezet houdt).")
            return

        try:
            sp_id = int(self.spin_sprite_id.get())
            sx = int(self.entry_x.get())
            sy = int(self.entry_y.get())
        except ValueError:
            messagebox.showerror("Fout", "Ongeldige Sprite ID of X/Y coördinaten.")
            return

        try:
            self.lbl_status.config(text=f"Bezig met uploaden naar FPGA op {port}...")
            self.update()
            with serial.Serial(port, 115200, timeout=0.5) as ser:
                # Selecteer sprite
                ser.write(f"PLOT 200,{sp_id},0\r".encode('ascii'))
                time.sleep(0.05)
                # Stuur 256 pixels in 16 compacte regels van 16 PLOTs
                idx = 0
                for y in range(16):
                    cmds = []
                    for x in range(16):
                        col = self.grid_data[y][x]
                        cmds.append(f"PLOT 203,{idx},{col}")
                        idx += 1
                    line_cmd = ":".join(cmds) + "\r"
                    ser.write(line_cmd.encode('ascii'))
                    time.sleep(0.08)
                # Zet op positie
                ser.write(f"PLOT 201,{sx},{sy}\r".encode('ascii'))
            self.lbl_status.config(text=f"🚀 Sprite {sp_id} staat nu LIVE op je FPGA scherm op ({sx}, {sy})!")
        except Exception as e:
            messagebox.showerror("Fout bij verbinden met FPGA", f"Kon niet naar {port} sturen:\n{e}\n\nTip: Staat minigpu_control.py nog open op dezelfde COM-poort?")

if __name__ == "__main__":
    app = SpriteStudioPro()
    app.mainloop()
