import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import serial
import serial.tools.list_ports
import threading
import time

class MiniGPUControl(tk.Tk):
    def __init__(self):
        super().__init__()
        
        self.title("MiniGPU BBC BASIC Control Panel")
        self.geometry("600x850")
        
        self.ser = None
        self.is_reading = False
        
        # --- COM Port Selection ---
        frame_com = ttk.LabelFrame(self, text="Verbinding")
        frame_com.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(frame_com, text="COM Poort:").grid(row=0, column=0, padx=5, pady=5)
        
        self.combo_ports = ttk.Combobox(frame_com, state="readonly")
        self.combo_ports.grid(row=0, column=1, padx=5, pady=5, sticky="ew")
        self.refresh_ports()
        
        self.btn_refresh = ttk.Button(frame_com, text="Vernieuw", command=self.refresh_ports)
        self.btn_refresh.grid(row=0, column=2, padx=5, pady=5)
        
        self.btn_connect = ttk.Button(frame_com, text="Verbinden", command=self.toggle_connection)
        self.btn_connect.grid(row=0, column=3, padx=5, pady=5)
        
        # --- Vrije Tekst / Terminal ---
        frame_text = ttk.LabelFrame(self, text="BBC BASIC Terminal (Typ Commando's)")
        frame_text.pack(fill="x", padx=10, pady=5)
        
        self.entry_text = ttk.Entry(frame_text)
        self.entry_text.pack(fill="x", padx=5, pady=5)
        self.entry_text.bind("<Return>", self.send_text)
        
        ttk.Button(frame_text, text="Stuur Commando (Enter)", command=self.send_text).pack(pady=5)
        
        # --- Programma Acties (Load/Save PC & MicroSD) ---
        frame_prog = ttk.LabelFrame(self, text="BBC BASIC Programma & MicroSD Opslag (6502 SD-MOS)")
        frame_prog.pack(fill="x", padx=10, pady=5)
        
        ttk.Button(frame_prog, text="Laden (PC -> FPGA)", command=self.load_program).grid(row=0, column=0, padx=5, pady=4)
        ttk.Button(frame_prog, text="Opslaan (FPGA -> PC)", command=self.save_program).grid(row=0, column=1, padx=5, pady=4)
        ttk.Button(frame_prog, text="*CAT (SD Lijst)", command=self.sd_cat).grid(row=0, column=2, padx=5, pady=4)
        ttk.Button(frame_prog, text="*WIPE (Wis SD)", command=self.sd_wipe).grid(row=0, column=3, padx=5, pady=4)

        ttk.Label(frame_prog, text="SD Bestandsnaam:").grid(row=1, column=0, padx=5, pady=4, sticky="e")
        self.entry_sd_name = ttk.Entry(frame_prog, width=14)
        self.entry_sd_name.grid(row=1, column=1, padx=5, pady=4, sticky="w")
        self.entry_sd_name.insert(0, "SDTEST")
        ttk.Button(frame_prog, text="SAVE naar SD", command=self.sd_save).grid(row=1, column=2, padx=5, pady=4)
        ttk.Button(frame_prog, text="LOAD van SD", command=self.sd_load).grid(row=1, column=3, padx=5, pady=4)
        
        # --- Cirkel Tekenaar ---
        frame_circle = ttk.LabelFrame(self, text="Hardware Cirkel Tekenen")
        frame_circle.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(frame_circle, text="Middelpunt X (0-1279):").grid(row=0, column=0, padx=5, pady=2, sticky="e")
        self.entry_cx = ttk.Entry(frame_circle, width=10)
        self.entry_cx.grid(row=0, column=1, padx=5, pady=2, sticky="w")
        self.entry_cx.insert(0, "640")
        
        ttk.Label(frame_circle, text="Middelpunt Y (0-1023):").grid(row=1, column=0, padx=5, pady=2, sticky="e")
        self.entry_cy = ttk.Entry(frame_circle, width=10)
        self.entry_cy.grid(row=1, column=1, padx=5, pady=2, sticky="w")
        self.entry_cy.insert(0, "512")
        
        ttk.Label(frame_circle, text="Straal / Radius:").grid(row=2, column=0, padx=5, pady=2, sticky="e")
        self.entry_r = ttk.Entry(frame_circle, width=10)
        self.entry_r.grid(row=2, column=1, padx=5, pady=2, sticky="w")
        self.entry_r.insert(0, "300")
        
        # --- Kleur Selectie ---
        ttk.Label(frame_circle, text="Kleur:").grid(row=3, column=0, padx=5, pady=2, sticky="e")
        self.combo_color = ttk.Combobox(frame_circle, state="readonly", width=15)
        self.colors = {
            "0 - Zwart": 0,
            "1 - Rood": 1,
            "2 - Groen": 2,
            "3 - Geel": 3,
            "4 - Blauw": 4,
            "5 - Magenta": 5,
            "6 - Cyaan": 6,
            "7 - Wit": 7
        }
        self.combo_color['values'] = list(self.colors.keys())
        self.combo_color.current(1) # Rood als standaard
        self.combo_color.grid(row=3, column=1, padx=5, pady=2, sticky="w")
        
        ttk.Button(frame_circle, text="Teken Cirkel!", command=self.draw_circle).grid(row=4, column=0, columnspan=2, pady=10)
        
        # --- Lijn Tekenen ---
        frame_line = ttk.LabelFrame(self, text="Hardware Lijn Tekenen")
        frame_line.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(frame_line, text="Start X (0-1279):").grid(row=0, column=0, padx=5, pady=2, sticky="e")
        self.entry_x1 = ttk.Entry(frame_line, width=10)
        self.entry_x1.grid(row=0, column=1, padx=5, pady=2, sticky="w")
        self.entry_x1.insert(0, "100")
        
        ttk.Label(frame_line, text="Start Y (0-1023):").grid(row=1, column=0, padx=5, pady=2, sticky="e")
        self.entry_y1 = ttk.Entry(frame_line, width=10)
        self.entry_y1.grid(row=1, column=1, padx=5, pady=2, sticky="w")
        self.entry_y1.insert(0, "100")
        
        ttk.Label(frame_line, text="Eind X (0-1279):").grid(row=0, column=2, padx=5, pady=2, sticky="e")
        self.entry_x2 = ttk.Entry(frame_line, width=10)
        self.entry_x2.grid(row=0, column=3, padx=5, pady=2, sticky="w")
        self.entry_x2.insert(0, "1000")
        
        ttk.Label(frame_line, text="Eind Y (0-1023):").grid(row=1, column=2, padx=5, pady=2, sticky="e")
        self.entry_y2 = ttk.Entry(frame_line, width=10)
        self.entry_y2.grid(row=1, column=3, padx=5, pady=2, sticky="w")
        self.entry_y2.insert(0, "900")
        
        ttk.Label(frame_line, text="Kleur:").grid(row=2, column=0, padx=5, pady=2, sticky="e")
        self.combo_line_color = ttk.Combobox(frame_line, state="readonly", width=15)
        self.combo_line_color['values'] = list(self.colors.keys())
        self.combo_line_color.current(2) # Groen als standaard
        self.combo_line_color.grid(row=2, column=1, padx=5, pady=2, sticky="w")
        
        ttk.Button(frame_line, text="Teken Lijn!", command=self.draw_line).grid(row=3, column=0, columnspan=4, pady=10)
        
        # --- Hardware Sprite ---
        frame_sprite = ttk.LabelFrame(self, text="Hardware Sprite Controls (0-15)")
        frame_sprite.pack(fill="x", padx=10, pady=5)
        
        ttk.Label(frame_sprite, text="Sprite ID:").grid(row=0, column=0, padx=5, pady=2, sticky="e")
        self.combo_sprite_id = ttk.Combobox(frame_sprite, state="readonly", width=5)
        self.combo_sprite_id['values'] = [str(i) for i in range(16)]
        self.combo_sprite_id.current(0)
        self.combo_sprite_id.grid(row=0, column=1, padx=5, pady=2, sticky="w")
        
        ttk.Label(frame_sprite, text="Sprite X:").grid(row=1, column=0, padx=5, pady=2, sticky="e")
        self.entry_sprite_x = ttk.Entry(frame_sprite, width=10)
        self.entry_sprite_x.grid(row=1, column=1, padx=5, pady=2, sticky="w")
        self.entry_sprite_x.insert(0, "640")
        
        ttk.Label(frame_sprite, text="Sprite Y:").grid(row=1, column=2, padx=5, pady=2, sticky="e")
        self.entry_sprite_y = ttk.Entry(frame_sprite, width=10)
        self.entry_sprite_y.grid(row=1, column=3, padx=5, pady=2, sticky="w")
        self.entry_sprite_y.insert(0, "512")
        
        ttk.Button(frame_sprite, text="Selecteer Sprite", command=self.select_sprite).grid(row=0, column=2, columnspan=2, pady=5, sticky="w")
        ttk.Button(frame_sprite, text="Zet Sprite!", command=self.set_sprite).grid(row=2, column=0, columnspan=2, pady=5)
        ttk.Button(frame_sprite, text="Verberg Sprite", command=self.disable_sprite).grid(row=2, column=2, columnspan=2, pady=5)
        
        # --- Scherm Acties ---
        frame_actions = ttk.LabelFrame(self, text="Scherm Acties")
        frame_actions.pack(fill="x", padx=10, pady=5)
        
        ttk.Button(frame_actions, text="Wis Tekst (CLS)", command=self.clear_text).grid(row=0, column=0, padx=5, pady=5)
        ttk.Button(frame_actions, text="Wis Achtergrond (CLG)", command=self.clear_graphics).grid(row=0, column=1, padx=5, pady=5)
        ttk.Button(frame_actions, text="Stop Programma (ESC)", command=self.send_escape).grid(row=0, column=2, padx=5, pady=5)
        
        # --- Debug Output ---
        frame_debug = ttk.LabelFrame(self, text="UART Ontvangst (FPGA -> PC)")
        frame_debug.pack(fill="both", expand=True, padx=10, pady=5)
        
        self.text_debug = tk.Text(frame_debug, height=10, wrap="word", state="disabled", bg="#1e1e1e", fg="#00ff00", font=("Consolas", 10))
        self.text_debug.pack(side="left", fill="both", expand=True, padx=5, pady=5)
        
        scrollbar = ttk.Scrollbar(frame_debug, command=self.text_debug.yview)
        scrollbar.pack(side="right", fill="y")
        self.text_debug.config(yscrollcommand=scrollbar.set)
        
        # --- Status ---
        self.lbl_status = ttk.Label(self, text="Niet verbonden.", foreground="red")
        self.lbl_status.pack(side="bottom", pady=10)

    def refresh_ports(self):
        ports = [port.device for port in serial.tools.list_ports.comports()]
        self.combo_ports['values'] = ports
        if ports:
            self.combo_ports.current(0)
            
    def toggle_connection(self):
        if self.ser is None:
            port = self.combo_ports.get()
            if not port:
                messagebox.showerror("Fout", "Geen COM poort geselecteerd!")
                return
            try:
                self.ser = serial.Serial(port, 115200, timeout=0.1)
                self.btn_connect.config(text="Verbreek Verbinding")
                self.combo_ports.config(state="disabled")
                self.btn_refresh.config(state="disabled")
                self.lbl_status.config(text=f"Verbonden met {port}", foreground="green")
                
                # Start lees thread
                self.is_reading = True
                threading.Thread(target=self.read_from_uart, daemon=True).start()
                
            except Exception as e:
                messagebox.showerror("Verbindingsfout", str(e))
        else:
            self.is_reading = False
            self.ser.close()
            self.ser = None
            self.btn_connect.config(text="Verbinden")
            self.combo_ports.config(state="readonly")
            self.btn_refresh.config(state="normal")
            self.lbl_status.config(text="Niet verbonden.", foreground="red")

    def read_from_uart(self):
        with open("uart_debug.log", "a", encoding="utf-8") as log_file:
            log_file.write("\n--- NIEUWE SESSIE ---\n")
            while self.is_reading and self.ser and self.ser.is_open:
                try:
                    data = self.ser.read(self.ser.in_waiting or 1)
                    if data:
                        # Vervang \r door \n voor betere weergave, decodeer met vervanging van foute tekens
                        text = data.replace(b'\r', b'\n').decode('utf-8', errors='replace')
                        
                        self.text_debug.config(state="normal")
                        self.text_debug.insert("end", text)
                        self.text_debug.see("end")
                        self.text_debug.config(state="disabled")
                        
                        # Schrijf ook direct naar een logbestand
                        log_file.write(text)
                        log_file.flush()
                except Exception:
                    break

    def send_text(self, event=None):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
            
        cmd = self.entry_text.get()
        if cmd:
            # Stuur het commando en een Enter (\r)
            full_cmd = cmd + "\r"
            try:
                self.ser.write(full_cmd.encode('ascii'))
                self.entry_text.delete(0, tk.END) # Maak veld leeg
            except Exception as e:
                messagebox.showerror("Fout bij verzenden", str(e))

    def load_program(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
            
        filepath = filedialog.askopenfilename(title="Kies een BASIC script", filetypes=[("Text/BASIC files", "*.txt *.bas"), ("All files", "*.*")])
        if not filepath:
            return
            
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            # Stuur het programma lijn voor lijn in een thread
            threading.Thread(target=self._send_lines_thread, args=(lines,), daemon=True).start()
            self.lbl_status.config(text=f"Bezig met inladen van {len(lines)} regels...", foreground="blue")
            
        except Exception as e:
            messagebox.showerror("Fout bij laden", str(e))

    def _send_lines_thread(self, lines):
        for line in lines:
            if not self.ser or not self.ser.is_open:
                break
            line = line.strip()
            if line:
                self.ser.write((line + "\r").encode('ascii'))
                if "CLG" in line.upper() or "CLS" in line.upper() or "MODE" in line.upper():
                    time.sleep(0.5) # Extra tijd om FPGA scherm te laten wissen (Voorkomt Race Condition)
                else:
                    time.sleep(0.1) # Wacht even zodat BBC Basic het kan verwerken
        
        # We kunnen de UI het beste updaten via self.after vanuit een thread
        self.after(0, lambda: self.lbl_status.config(text="Programma succesvol geladen!", foreground="green"))

    def save_program(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
            
        filepath = filedialog.asksaveasfilename(title="Sla BASIC script op", defaultextension=".txt", filetypes=[("Text files", "*.txt"), ("All files", "*.*")])
        if not filepath:
            return
            
        self.lbl_status.config(text="Programma aan het opvragen... een moment geduld.", foreground="blue")
        
        try:
            # Stuur LIST commando
            self.ser.write(b"LIST\r")
            # Wacht 2.5 seconden en verwerk de tekst
            self.after(2500, lambda: self._process_save(filepath))
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def _process_save(self, filepath):
        try:
            content = self.text_debug.get("1.0", tk.END)
            idx = content.rfind("LIST")
            if idx != -1:
                list_content = content[idx:]
                end_idx = list_content.rfind(">")
                if end_idx != -1:
                    list_content = list_content[:end_idx]
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    lines = list_content.split('\n')
                    for line in lines:
                        line = line.strip()
                        if line and line != "LIST":
                            f.write(line + "\n")
                            
                self.lbl_status.config(text=f"Succesvol opgeslagen als {filepath}!", foreground="green")
            else:
                self.lbl_status.config(text="Kon LIST output niet vinden (programma te lang of leeg).", foreground="red")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def draw_circle(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
            
        try:
            x = int(self.entry_cx.get())
            y = int(self.entry_cy.get())
            r = int(self.entry_r.get())
            
            # Haal het kleurnummer op uit de dropdown
            color_name = self.combo_color.get()
            color_num = self.colors[color_name]
            
            # Formatteer het BBC Basic commando met het NIEUWE native CIRCLE commando
            cmd = f"GCOL 0, {color_num}: CIRCLE {x},{y},{r}\r"
            
            self.ser.write(cmd.encode('ascii'))
            self.lbl_status.config(text=f"Cirkel getekend op ({x},{y}) met straal {r} in kleur {color_num}!", foreground="blue")
            
        except ValueError:
            messagebox.showerror("Ongeldige invoer", "Vul aub alleen hele getallen in bij de cirkel-velden.")
        except Exception as e:
            messagebox.showerror("Fout bij verzenden", str(e))

    def draw_line(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
            
        try:
            x1 = int(self.entry_x1.get())
            y1 = int(self.entry_y1.get())
            x2 = int(self.entry_x2.get())
            y2 = int(self.entry_y2.get())
            
            # Haal het kleurnummer op uit de dropdown
            color_name = self.combo_line_color.get()
            color_num = self.colors[color_name]
            
            # Formatteer het BBC Basic commando met het NIEUWE native GLINE commando
            cmd = f"GCOL 0, {color_num}: GLINE {x1},{y1},{x2},{y2}\r"
            
            self.ser.write(cmd.encode('ascii'))
            self.lbl_status.config(text=f"Lijn getekend van ({x1},{y1}) naar ({x2},{y2}) in kleur {color_num}!", foreground="blue")
            
        except ValueError:
            messagebox.showerror("Ongeldige invoer", "Vul aub alleen hele getallen in bij de lijn-velden.")
        except Exception as e:
            messagebox.showerror("Fout bij verzenden", str(e))

    def select_sprite(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            sprite_id = int(self.combo_sprite_id.get())
            cmd = f"PLOT 200,{sprite_id},0\r"
            self.ser.write(cmd.encode('ascii'))
            self.lbl_status.config(text=f"Sprite {sprite_id} geselecteerd!", foreground="blue")
        except ValueError:
            pass
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def set_sprite(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            sprite_id = int(self.combo_sprite_id.get())
            x = int(self.entry_sprite_x.get())
            y = int(self.entry_sprite_y.get())
            # Eerst ID selecteren, dan X,Y instellen
            cmd = f"PLOT 200,{sprite_id},0\rPLOT 201,{x},{y}\r"
            self.ser.write(cmd.encode('ascii'))
            self.lbl_status.config(text=f"Sprite {sprite_id} gezet op ({x},{y})", foreground="blue")
        except ValueError:
            messagebox.showerror("Ongeldige invoer", "Vul aub alleen hele getallen in.")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def disable_sprite(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            sprite_id = int(self.combo_sprite_id.get())
            cmd = f"PLOT 200,{sprite_id},0\rPLOT 202,0,0\r"
            self.ser.write(cmd.encode('ascii'))
            self.lbl_status.config(text=f"Sprite {sprite_id} verborgen!", foreground="blue")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def clear_text(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            self.ser.write(b"CLS\r")
            self.lbl_status.config(text="Tekstlaag gewist (CLS)!", foreground="blue")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def clear_graphics(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            self.ser.write(b"CLG\r")
            self.lbl_status.config(text="Achtergrond/grafische laag gewist (CLG)!", foreground="blue")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def sd_save(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        name = self.entry_sd_name.get().strip().upper()[:12] or "PROG"
        try:
            self.ser.write(f'SAVE "{name}"\r'.encode('ascii'))
            self.lbl_status.config(text=f'SAVE "{name}" verstuurd naar 6502 SD-MOS!', foreground="blue")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def sd_load(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        name = self.entry_sd_name.get().strip().upper()[:12] or "PROG"
        try:
            self.ser.write(f'LOAD "{name}"\r'.encode('ascii'))
            self.lbl_status.config(text=f'LOAD "{name}" verstuurd naar 6502 SD-MOS!', foreground="blue")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def sd_cat(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            self.ser.write(b"*CAT\r")
            self.lbl_status.config(text="*CAT (SD Catalogus) opgevraagd!", foreground="blue")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

    def sd_wipe(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        if messagebox.askyesno("Bevestig *WIPE", "Weet je zeker dat je de SD-MOS bestandslijst wilt wissen (*WIPE)?"):
            try:
                self.ser.write(b"*WIPE\r")
                self.lbl_status.config(text="*WIPE uitgevoerd!", foreground="orange")
            except Exception as e:
                messagebox.showerror("Fout", str(e))

    def send_escape(self):
        if self.ser is None:
            messagebox.showwarning("Let op", "Maak eerst verbinding!")
            return
        try:
            self.ser.write(b"\x1B")
            self.lbl_status.config(text="Escape verstuurd! (Programma afgebroken)", foreground="red")
        except Exception as e:
            messagebox.showerror("Fout", str(e))

if __name__ == "__main__":
    app = MiniGPUControl()
    app.mainloop()
