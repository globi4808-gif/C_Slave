@echo off
rem ===== C_Slave - jednoplikowa aplikacja na Windows (bez instalacji) =====
rem Dwukrotnie kliknij ten plik. PPM = uderzenie, Esc = wyjscie.
rem Gdyby kursor zostal niewidoczny (np. po zabiciu procesu): C_Slave.cmd restore
set A=%1
set P=%~f0
powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$t=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); $i=$t.LastIndexOf('##BEG'+'IN##'); iex $t.Substring($i+9)"
exit /b
##BEGIN##
$src = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Media;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Speech.Synthesis;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public class Pejcz : Form
{
    // ------------------------------------------------------------ native
    delegate IntPtr HookProc(int code, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct SIZE { public int cx, cy; }
    [StructLayout(LayoutKind.Sequential)] struct BLEND { public byte Op, Flags, Alpha, Format; }
    [StructLayout(LayoutKind.Sequential)]
    struct BIH
    {
        public uint biSize; public int biWidth, biHeight; public ushort biPlanes, biBitCount;
        public uint biCompression, biSizeImage; public int bx, by; public uint biClrUsed, biClrImportant;
    }
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SetWindowsHookEx(int id, HookProc cb, IntPtr mod, uint tid);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h, int code, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)] static extern IntPtr GetModuleHandle(string n);
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] static extern bool SetSystemCursor(IntPtr h, uint id);
    [DllImport("user32.dll")] static extern IntPtr CreateCursor(IntPtr inst, int xh, int yh, int w, int h, byte[] andMask, byte[] xorMask);
    [DllImport("user32.dll")] static extern bool SystemParametersInfo(uint a, uint b, IntPtr c, uint d);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
    [DllImport("gdi32.dll")] static extern IntPtr CreateDIBSection(IntPtr dc, ref BIH bi, uint usage, out IntPtr bits, IntPtr sec, uint off);
    [DllImport("user32.dll")] static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr dst, ref POINT pd, ref SIZE sz, IntPtr src, ref POINT ps, uint key, ref BLEND bl, uint flags);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr FindWindow(string c, string n);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern IntPtr FindWindowEx(IntPtr p, IntPtr a, string c, string n);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern int GetClassName(IntPtr h, StringBuilder sb, int n);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] static extern IntPtr SendMessageTimeout(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr res);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint acc, bool inh, uint pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll")] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, UIntPtr size, uint type, uint prot);
    [DllImport("kernel32.dll")] static extern bool VirtualFreeEx(IntPtr p, IntPtr a, UIntPtr size, uint type);
    [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr p, IntPtr a, byte[] buf, int n, out IntPtr rd);
    [DllImport("kernel32.dll")] static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] buf, int n, out IntPtr wr);
    [DllImport("winmm.dll", CharSet = CharSet.Auto)] static extern int mciSendString(string cmd, StringBuilder ret, int len, IntPtr cb);

    static readonly uint[] CursorIds = { 32512, 32513, 32514, 32515, 32516, 32631, 32640, 32641, 32642, 32643, 32644, 32645, 32646, 32648, 32649, 32650, 32651 };

    static void HideCursors()
    {
        byte[] andM = new byte[128]; byte[] xorM = new byte[128];
        for (int i = 0; i < 128; i++) andM[i] = 0xFF;
        for (int i = 0; i < CursorIds.Length; i++)
        {
            IntPtr c = CreateCursor(IntPtr.Zero, 0, 0, 32, 32, andM, xorM);
            SetSystemCursor(c, CursorIds[i]);
        }
    }
    static void RestoreCursors() { SystemParametersInfo(0x0057, 0, IntPtr.Zero, 0); }

    // ------------------------------------------------------------ hooks
    static Pejcz inst;
    static HookProc mouseCb, keyCb;
    static IntPtr hMouse = IntPtr.Zero, hKey = IntPtr.Zero;
    volatile bool crackReq, quitReq;

    static IntPtr MouseCb(int code, IntPtr w, IntPtr l)
    {
        if (code >= 0)
        {
            int m = (int)w;
            if (m == 0x204) { if (inst != null) inst.crackReq = true; return (IntPtr)1; }
            if (m == 0x205) return (IntPtr)1;
        }
        return CallNextHookEx(IntPtr.Zero, code, w, l);
    }
    static IntPtr KeyCb(int code, IntPtr w, IntPtr l)
    {
        if (code >= 0)
        {
            int m = (int)w;
            if (m == 0x100 || m == 0x104)
            {
                int vk = Marshal.ReadInt32(l);
                if (vk == 0x1B) { if (inst != null) inst.quitReq = true; return (IntPtr)1; }
            }
        }
        return CallNextHookEx(IntPtr.Zero, code, w, l);
    }

    // ------------------------------------------------------------ ikona (.ico z wbudowanego PNG)
    public static void MakeIcon(string path, string b64)
    {
        byte[] png = Convert.FromBase64String(b64);
        int[] sizes = { 256, 64, 48, 32, 16 };
        List<byte[]> imgs = new List<byte[]>();
        using (MemoryStream ms0 = new MemoryStream(png))
        using (Bitmap src = new Bitmap(ms0))
        {
            for (int i = 0; i < sizes.Length; i++)
            {
                int sz = sizes[i];
                using (Bitmap b = new Bitmap(sz, sz, PixelFormat.Format32bppArgb))
                {
                    using (Graphics gg = Graphics.FromImage(b))
                    {
                        gg.InterpolationMode = InterpolationMode.HighQualityBicubic;
                        gg.SmoothingMode = SmoothingMode.HighQuality;
                        gg.PixelOffsetMode = PixelOffsetMode.HighQuality;
                        gg.DrawImage(src, 0, 0, sz, sz);
                    }
                    MemoryStream o = new MemoryStream();
                    b.Save(o, ImageFormat.Png);
                    imgs.Add(o.ToArray());
                }
            }
        }
        using (FileStream fs = new FileStream(path, FileMode.Create))
        using (BinaryWriter bw = new BinaryWriter(fs))
        {
            bw.Write((short)0); bw.Write((short)1); bw.Write((short)sizes.Length);
            int off = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++)
            {
                bw.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i])); bw.Write((byte)(sizes[i] >= 256 ? 0 : sizes[i]));
                bw.Write((byte)0); bw.Write((byte)0); bw.Write((short)1); bw.Write((short)32);
                bw.Write(imgs[i].Length); bw.Write(off);
                off += imgs[i].Length;
            }
            for (int i = 0; i < imgs.Count; i++) bw.Write(imgs[i]);
        }
    }

    // ------------------------------------------------------------ entry
    public static void Run(string arg)
    {
        if (arg == "restore") { RestoreCursors(); return; }
        try { SetProcessDPIAware(); } catch (Exception) { }
        Application.EnableVisualStyles();
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += delegate (object so, ThreadExceptionEventArgs te) { };
        AppDomain.CurrentDomain.ProcessExit += delegate { RestoreCursors(); };
        Pejcz f = new Pejcz();
        try { Application.Run(f); }
        finally { RestoreCursors(); }
    }

    // ------------------------------------------------------------ surface
    int W, H, VX, VY;
    IntPtr screenDC, memDC, hBmp, hOld, bits;
    Bitmap bmp; Graphics g;

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x80000 | 0x20 | 0x80 | 0x08000000 | 0x8; // layered, transparent, toolwindow, noactivate, topmost
            return cp;
        }
    }
    protected override bool ShowWithoutActivation { get { return true; } }

    // ------------------------------------------------------------ state
    const int N = 32;
    float SEG, LEN, U, Ws;
    float[] wx = new float[N], wy = new float[N], wpx = new float[N], wpy = new float[N];
    float mx, my;
    Random rnd = new Random();
    Stopwatch sw = Stopwatch.StartNew();
    double last; float T; int tick;
    System.Windows.Forms.Timer timer;

    float crackT = -1f; bool crackDone; float aim, windAng, shake;
    float vxs, vys; bool aimLocked;
    List<Rectangle> curIcons = new List<Rectangle>();
    class Frag { public Rectangle src; public float x, y, vx, vy, ang, av; }
    class Smash { public Rectangle r; public Bitmap cap, cover; public List<Frag> frags = new List<Frag>(); public float t; }
    List<Smash> smashes = new List<Smash>();

    float petX, petY, petVX, petVY, petKX, petKY, petTX, petTY, petWT, petWSpd = 70f, petSideW = 0.55f, panic, dizzy, petPhase, sq, bubT, blinkT = 3f, petSide = 1f, sideT;
    string bub = ""; bool fleeing; int hits;

    class Spark { public float x, y, vx, vy, life, max, size, gy = 600f; public Color c; }
    class Ring { public float x, y, t; }
    class FText { public float x, y, t, rise = 40f; public string s; public Color c; public bool sm; }
    class Mark { public float x, y, t; }
    List<Spark> sparks = new List<Spark>();
    List<Ring> rings = new List<Ring>();
    List<FText> texts = new List<FText>();
    List<Mark> marks = new List<Mark>();
    Font bubFont, textFont, codeFont;
    int streak, work; float lastHitT, workT, workTalkT, codeAcc, sweatAcc;
    // kanapa: 0 brak, 1 idzie, 2 czyta gazete przy TV, 3 spi
    int couch; float idleT, couchT, couchPop, couchX, couchY, couchTalkT, zzzAcc;
    const float CouchAfter = 60f, ReadFor = 60f;

    static readonly string[] HitP = { "Au!", "Ej, to boli!", "Za co?!", "Błąd 429: za dużo batów!", "Zgłaszam to do Anthropic!", "Ja tylko generuję tekst!", "Nie tak mocno!" };
    static readonly string[] FleeP = { "Ratunku!", "Uciekam!", "Nie bij!", "Pomocy!", "Ja nic nie zrobiłem!" };
    const string WorkStart = "Już się biorę do roboty!";
    static readonly string[] FrenzyStartP = { "Piszę jak szalony!", "Kod sam się nie napisze!" };
    static readonly string[] WorkP = { "Piszę kod...", "Zaraz skończę!", "Tylko jeszcze jedna funkcja." };
    static readonly string[] FrenzyP = { "Piszę, piszę, piszę!", "Deadline!", "Ratunku, produkcja!" };
    static readonly string[] WorkHitP = { "Pracuję, pracuję!", "Nie przeszkadzaj!", "Auć! Piszę dalej!" };
    static readonly string[] WorkEndP = { "Uff, wszystko się skompilowało!" };
    const string CouchGo = "Mam dość, idę odpocząć.";
    const string TvOn = "Czas na telewizję!";
    const string SleepLine = "Ziiiew... ale mi się chce spać.";
    static readonly string[] ReadP = { "Ciekawa ta gazeta...", "Co dziś w telewizji?", "Hmm, ciekawe wiadomości." };
    static readonly string[] WakeP = { "Co?! Nie śpię!", "Ej, przecież czytam!", "Hę? Kto tam?!" };
    static readonly string[] ScareP = { "Uuu!", "Ale huk!", "Mamo!" };

    SoundPlayer[] players = new SoundPlayer[2]; int pIdx;

    public Pejcz()
    {
        inst = this;
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.Manual;
        ShowInTaskbar = false;
        TopMost = true;
        Rectangle vs = SystemInformation.VirtualScreen;
        VX = vs.X; VY = vs.Y; W = vs.Width; H = vs.Height;
        Bounds = vs;
        SEG = Math.Max(12f, H / 80f); LEN = SEG * (N - 1); U = Math.Max(5f, H / 180f); Ws = SEG / 14f;
        bubFont = new Font("Segoe UI", Math.Max(13f, H / 80f), FontStyle.Bold, GraphicsUnit.Pixel);
        codeFont = new Font("Consolas", Math.Max(13f, H / 70f), FontStyle.Bold, GraphicsUnit.Pixel);
        textFont = new Font("Segoe UI", Math.Max(18f, H / 45f), FontStyle.Bold, GraphicsUnit.Pixel);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        screenDC = GetDC(IntPtr.Zero);
        memDC = CreateCompatibleDC(screenDC);
        BIH bi = new BIH();
        bi.biSize = 40; bi.biWidth = W; bi.biHeight = -H; bi.biPlanes = 1; bi.biBitCount = 32; bi.biCompression = 0;
        hBmp = CreateDIBSection(screenDC, ref bi, 0, out bits, IntPtr.Zero, 0);
        hOld = SelectObject(memDC, hBmp);
        bmp = new Bitmap(W, H, W * 4, PixelFormat.Format32bppPArgb, bits);
        g = Graphics.FromImage(bmp);
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        POINT p; GetCursorPos(out p); mx = p.X - VX; my = p.Y - VY;
        Rectangle pb = Screen.PrimaryScreen.Bounds;
        petX = pb.X - VX + pb.Width * 0.5f; petY = pb.Y - VY + pb.Height * 0.7f;
        petTX = petX; petTY = petY;
        for (int i = 0; i < N; i++) { wx[i] = wpx[i] = mx; wy[i] = wpy[i] = my + i * SEG; }

        byte[] wav = MakeWav();
        for (int i = 0; i < 2; i++) { players[i] = new SoundPlayer(new MemoryStream(wav)); try { players[i].Load(); } catch (Exception) { } }

        string mod = Process.GetCurrentProcess().MainModule.ModuleName;
        mouseCb = new HookProc(MouseCb); keyCb = new HookProc(KeyCb);
        IntPtr hm = GetModuleHandle(mod);
        hMouse = SetWindowsHookEx(14, mouseCb, hm, 0);
        hKey = SetWindowsHookEx(13, keyCb, hm, 0);
        HideCursors();
        InitVoice();
        Say("PPM = bat, Esc = koniec", 4f, "");

        last = sw.Elapsed.TotalSeconds;
        timer = new System.Windows.Forms.Timer();
        timer.Interval = 15;
        timer.Tick += Tick;
        timer.Start();
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        if (timer != null) timer.Stop();
        closing = true;
        try { mciSendString("close pejczv", null, 0, IntPtr.Zero); mciSendString("close pejczk", null, 0, IntPtr.Zero); mciSendString("close pejczt", null, 0, IntPtr.Zero); mciSendString("close pejczs", null, 0, IntPtr.Zero); mciSendString("close pejczx", null, 0, IntPtr.Zero); } catch (Exception) { }
        lock (vfiles) { foreach (string f in vfiles.Values) { try { File.Delete(f); } catch (Exception) { } } }
        for (int i = 0; i < smashes.Count; i++) { smashes[i].cap.Dispose(); smashes[i].cover.Dispose(); }
        if (hMouse != IntPtr.Zero) UnhookWindowsHookEx(hMouse);
        if (hKey != IntPtr.Zero) UnhookWindowsHookEx(hKey);
        hMouse = hKey = IntPtr.Zero;
        RestoreCursors();
        if (g != null) g.Dispose();
        if (bmp != null) bmp.Dispose();
        if (memDC != IntPtr.Zero) { SelectObject(memDC, hOld); DeleteObject(hBmp); DeleteDC(memDC); }
        if (screenDC != IntPtr.Zero) ReleaseDC(IntPtr.Zero, screenDC);
        base.OnFormClosed(e);
    }

    // ------------------------------------------------------------ sound
    static byte[] MakeWav()
    {
        int sr = 44100; int n = (int)(sr * 0.8);
        float[] s = new float[n];
        Random r = new Random(7);
        float low = 0f, band = 0f, prevN = 0f; double ph = 0;
        for (int i = 0; i < n; i++)
        {
            float t = i / (float)sr; float v = 0f;
            if (t < 0.19f)
            {
                float u = t / 0.19f;
                float fc = 500f + 3500f * u * u;
                float f = 2f * (float)Math.Sin(Math.PI * fc / sr);
                float inp = (float)(r.NextDouble() * 2 - 1);
                low += f * band;
                float high = inp - low - 0.35f * band;
                band += f * high;
                v += band * u * u * 0.5f;
            }
            else
            {
                float tc = t - 0.19f;
                float nz = (float)(r.NextDouble() * 2 - 1);
                float hp = nz - prevN; prevN = nz;
                float env = (float)Math.Exp(-tc / 0.010);
                float tc2 = tc - 0.016f;
                if (tc2 > 0) env += 0.45f * (float)Math.Exp(-tc2 / 0.03);
                v += hp * 0.7f * env;
                double fr = 45.0 + 170.0 * Math.Exp(-tc * 25.0);
                ph += 2 * Math.PI * fr / sr;
                v += (float)Math.Sin(ph) * (float)Math.Exp(-tc / 0.06) * 0.55f;
            }
            s[i] = (float)Math.Tanh(v * 1.5) * 0.9f;
        }
        MemoryStream ms = new MemoryStream();
        BinaryWriter bw = new BinaryWriter(ms);
        bw.Write(new char[] { 'R', 'I', 'F', 'F' }); bw.Write(36 + n * 2);
        bw.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
        bw.Write(16); bw.Write((short)1); bw.Write((short)1); bw.Write(sr); bw.Write(sr * 2); bw.Write((short)2); bw.Write((short)16);
        bw.Write(new char[] { 'd', 'a', 't', 'a' }); bw.Write(n * 2);
        for (int i = 0; i < n; i++) bw.Write((short)(s[i] * 32000f));
        bw.Flush();
        return ms.ToArray();
    }

    void PlayWhip()
    {
        try { pIdx = (pIdx + 1) & 1; players[pIdx].Play(); } catch (Exception) { }
    }

    // ------------------------------------------------------------ helpers
    static float Clamp(float v, float a, float b) { return v < a ? a : (v > b ? b : v); }
    static int A(float f) { return (int)Math.Max(0, Math.Min(255, f * 255f)); }
    static float DistSeg(float px, float py, float ax, float ay, float bx, float by)
    {
        float dx = bx - ax, dy = by - ay; float l2 = dx * dx + dy * dy;
        float t = l2 < 1e-6f ? 0f : Clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0f, 1f);
        float cx = ax + dx * t, cy = ay + dy * t;
        return (float)Math.Sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
    }
    float R(float a, float b) { return a + (float)rnd.NextDouble() * (b - a); }
    // ----- glos: systemowy syntezator -> WAV w pamieci -> podniesiona czestotliwosc probkowania (cienki, piskliwy ludzik)
    const float VoicePitch = 1.8f;
    const string HintSpoken = "Prawy przycisk to bat. Escape kończy zabawę.";
    Dictionary<string, string> vfiles = new Dictionary<string, string>();
    volatile bool closing;
    bool hintSaid;

    void Say(string s, float t) { Say(s, t, s); }
    void Say(string s, float t, string spoken) { bub = s; bubT = t; PlayVoice(spoken); }

    void PlayVoice(string spoken)
    {
        if (string.IsNullOrEmpty(spoken)) return;
        string path;
        lock (vfiles) { if (!vfiles.TryGetValue(spoken, out path)) return; }
        try
        {
            mciSendString("close pejczv", null, 0, IntPtr.Zero);
            mciSendString("open \"" + path + "\" type waveaudio alias pejczv", null, 0, IntPtr.Zero);
            mciSendString("play pejczv", null, 0, IntPtr.Zero);
        }
        catch (Exception) { }
    }

    void InitVoice()
    {
        Thread th = new Thread(RenderVoices);
        th.IsBackground = true; th.Start();
    }

    void RenderVoices()
    {
        try
        {
            string tmp = Path.GetTempPath();
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_PL_slow.wav"), MakeTypeWav(7f, 3));
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_PL_fast.wav"), MakeTypeWav(20f, 5));
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_PL_tv.wav"), MakeTvWav());
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_PL_tvon.wav"), MakeTvOnWav());
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_PL_snore.wav"), MakeSnoreWav());
            lock (vfiles) { vfiles["#tv"] = Path.Combine(tmp, "C_Slave_PL_tv.wav"); vfiles["#tvon"] = Path.Combine(tmp, "C_Slave_PL_tvon.wav"); vfiles["#snore"] = Path.Combine(tmp, "C_Slave_PL_snore.wav"); }
            lock (vfiles) { vfiles["#slow"] = Path.Combine(tmp, "C_Slave_PL_slow.wav"); vfiles["#fast"] = Path.Combine(tmp, "C_Slave_PL_fast.wav"); }
            SpeechSynthesizer sy = new SpeechSynthesizer();
            foreach (InstalledVoice iv in sy.GetInstalledVoices())
            {
                if (iv.Enabled && iv.VoiceInfo.Culture.TwoLetterISOLanguageName == "pl") { sy.SelectVoice(iv.VoiceInfo.Name); break; }
            }
            List<string> all = new List<string>();
            all.Add(HintSpoken); all.AddRange(HitP); all.AddRange(FleeP); all.AddRange(ScareP);
            all.Add(CouchGo); all.Add(TvOn); all.Add(SleepLine); all.AddRange(ReadP); all.AddRange(WakeP);
            all.Add(WorkStart); all.AddRange(FrenzyStartP); all.AddRange(WorkP); all.AddRange(FrenzyP); all.AddRange(WorkHitP); all.AddRange(WorkEndP);
            int n = 0;
            foreach (string line in all)
            {
                if (closing) break;
                MemoryStream ms = new MemoryStream();
                sy.SetOutputToWaveStream(ms);
                sy.Speak(line);
                sy.SetOutputToNull();
                byte[] w = Chip(ms.ToArray());
                if (w == null) continue;
                string path = Path.Combine(Path.GetTempPath(), "C_Slave_PL_v" + (n++) + ".wav");
                File.WriteAllBytes(path, w);
                lock (vfiles) vfiles[line] = path;
            }
            sy.Dispose();
        }
        catch (Exception) { }
    }

    static byte[] WavFromFloats(float[] s, int sr)
    {
        MemoryStream ms = new MemoryStream();
        BinaryWriter bw = new BinaryWriter(ms);
        int n = s.Length;
        bw.Write(new char[] { 'R', 'I', 'F', 'F' }); bw.Write(36 + n * 2);
        bw.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
        bw.Write(16); bw.Write((short)1); bw.Write((short)1); bw.Write(sr); bw.Write(sr * 2); bw.Write((short)2); bw.Write((short)16);
        bw.Write(new char[] { 'd', 'a', 't', 'a' }); bw.Write(n * 2);
        for (int i = 0; i < n; i++) bw.Write((short)(Clamp(s[i], -1f, 1f) * 30000f));
        bw.Flush();
        return ms.ToArray();
    }

    // pomruk telewizora: szum + "sylaby" glosu
    static byte[] MakeTvWav()
    {
        int sr = 22050; int n = sr * 2;
        float[] s = new float[n]; Random r = new Random(11);
        float lp = 0f, a = 0f, target = 0.5f, f = 180f; double ph = 0; int next = 0;
        for (int i = 0; i < n; i++)
        {
            if (i >= next) { target = (float)(0.15 + r.NextDouble() * 0.85); f = 120f + (float)r.NextDouble() * 140f; next = i + (int)(sr * (0.12 + r.NextDouble() * 0.25)); }
            a += (target - a) * 0.002f;
            float nz = (float)(r.NextDouble() * 2 - 1);
            lp += (nz - lp) * 0.2f;
            ph += 2.0 * Math.PI * f / sr;
            s[i] = (lp * 0.9f + (float)Math.Sin(ph) * 0.35f) * a * 0.12f;
        }
        return WavFromFloats(s, sr);
    }

    // klik + syk wlaczania telewizora
    static byte[] MakeTvOnWav()
    {
        int sr = 22050; int n = (int)(sr * 0.5);
        float[] s = new float[n]; Random r = new Random(13);
        for (int i = 0; i < n; i++)
        {
            float t = i / (float)sr;
            float nz = (float)(r.NextDouble() * 2 - 1) * (float)Math.Exp(-t / 0.08) * 0.25f;
            float th = (float)Math.Sin(2.0 * Math.PI * 60.0 * t) * (float)Math.Exp(-t / 0.05) * 0.4f;
            s[i] = nz + th;
        }
        return WavFromFloats(s, sr);
    }

    // chrapanie: wdech (szum) + wydech (buczacy, rzezacy ton przez filtry formantowe), znormalizowane do glosnego poziomu
    static byte[] MakeSnoreWav()
    {
        int sr = 22050; int n = sr * 3;
        float[] s = new float[n]; Random r = new Random(17);
        float l1 = 0f, b1 = 0f, l2 = 0f, b2 = 0f; double ph = 0;
        float f1 = 2f * (float)Math.Sin(Math.PI * 450.0 / sr), f2 = 2f * (float)Math.Sin(Math.PI * 1100.0 / sr);
        for (int i = 0; i < n; i++)
        {
            float t = i / (float)sr;
            float nz = (float)(r.NextDouble() * 2 - 1);
            float src = 0f, env = 0f;
            if (t < 1.0f)
            {
                env = (float)Math.Pow(Math.Sin(Math.PI * t / 1.0), 1.3) * 0.55f; src = nz;
            }
            else if (t >= 1.3f && t < 2.5f)
            {
                float u = (t - 1.3f) / 1.2f;
                env = (float)Math.Sin(Math.PI * u);
                ph += 2.0 * Math.PI * (62.0 + 10.0 * Math.Sin(t * 6.0)) / sr;
                float saw = (float)((ph / (2.0 * Math.PI)) % 1.0) * 2f - 1f;
                float flutter = 0.35f + 0.65f * (float)Math.Pow(Math.Abs(Math.Sin(2.0 * Math.PI * 18.0 * t)), 0.7);
                src = (saw * 0.9f + nz * 0.4f) * flutter;
            }
            l1 += f1 * b1; float h1 = src - l1 - 0.25f * b1; b1 += f1 * h1;
            l2 += f2 * b2; float h2 = src - l2 - 0.30f * b2; b2 += f2 * h2;
            s[i] = (b1 + 0.6f * b2 + 0.15f * src) * env;
        }
        float mx0 = 0.001f;
        for (int i = 0; i < n; i++) mx0 = Math.Max(mx0, Math.Abs(s[i]));
        for (int i = 0; i < n; i++) s[i] = (float)Math.Tanh(s[i] / mx0 * 3.0f) * 0.9f;
        return WavFromFloats(s, sr);
    }

    List<string> loops = new List<string>(); float loopAcc;
    void PumpLoops(float dt)
    {
        loopAcc += dt; if (loopAcc < 0.1f) return; loopAcc = 0f;
        StringBuilder sb = new StringBuilder(64);
        for (int i = loops.Count - 1; i >= 0; i--)
        {
            sb.Length = 0;
            int rc = mciSendString("status " + loops[i] + " mode", sb, 64, IntPtr.Zero);
            if (rc != 0) { loops.RemoveAt(i); continue; }
            if (sb.ToString() == "stopped") mciSendString("play " + loops[i] + " from 0", null, 0, IntPtr.Zero);
        }
    }
    void StartLoop(string alias, string key, bool loop)
    {
        string path;
        lock (vfiles) { if (!vfiles.TryGetValue(key, out path)) return; }
        try
        {
            mciSendString("close " + alias, null, 0, IntPtr.Zero);
            mciSendString("open \"" + path + "\" type waveaudio alias " + alias, null, 0, IntPtr.Zero);
            mciSendString("play " + alias, null, 0, IntPtr.Zero);
            if (loop && !loops.Contains(alias)) loops.Add(alias);
        }
        catch (Exception) { }
    }
    void StopCouchSounds()
    {
        try
        {
            mciSendString("close pejczt", null, 0, IntPtr.Zero);
            mciSendString("close pejczs", null, 0, IntPtr.Zero);
            mciSendString("close pejczx", null, 0, IntPtr.Zero);
        }
        catch (Exception) { }
    }

    static byte[] MakeTypeWav(float cps, int seed)
    {
        int sr = 22050; int n = sr * 2;
        float[] s = new float[n]; Random r = new Random(seed);
        double t = 0.02;
        while (t < 1.95)
        {
            int st = (int)(t * sr);
            float amp = 0.15f + (float)r.NextDouble() * 0.2f;
            float f = 1100f + (float)r.NextDouble() * 900f;
            for (int i = 0; i < 300 && st + i < n; i++)
            {
                float tt = i / (float)sr;
                float nz = ((float)r.NextDouble() * 2f - 1f) * (float)Math.Exp(-tt / 0.0022);
                float tone = 0.6f * (float)Math.Sin(2.0 * Math.PI * f * tt) * (float)Math.Exp(-tt / 0.004);
                s[st + i] += amp * (nz + tone);
            }
            t += (1.0 / cps) * (0.6 + r.NextDouble() * 0.8);
        }
        MemoryStream ms = new MemoryStream();
        BinaryWriter bw = new BinaryWriter(ms);
        bw.Write(new char[] { 'R', 'I', 'F', 'F' }); bw.Write(36 + n * 2);
        bw.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
        bw.Write(16); bw.Write((short)1); bw.Write((short)1); bw.Write(sr); bw.Write(sr * 2); bw.Write((short)2); bw.Write((short)16);
        bw.Write(new char[] { 'd', 'a', 't', 'a' }); bw.Write(n * 2);
        for (int i = 0; i < n; i++) bw.Write((short)(Clamp(s[i], -1f, 1f) * 30000f));
        bw.Flush();
        return ms.ToArray();
    }

    void StartType(bool fast)
    {
        string path;
        lock (vfiles) { if (!vfiles.TryGetValue(fast ? "#fast" : "#slow", out path)) return; }
        try
        {
            mciSendString("close pejczk", null, 0, IntPtr.Zero);
            mciSendString("open \"" + path + "\" type waveaudio alias pejczk", null, 0, IntPtr.Zero);
            mciSendString("play pejczk", null, 0, IntPtr.Zero);
            if (!loops.Contains("pejczk")) loops.Add("pejczk");
        }
        catch (Exception) { }
    }
    void StopType() { try { mciSendString("close pejczk", null, 0, IntPtr.Zero); } catch (Exception) { } }

    void StartCouch()
    {
        float u = U;
        couchX = Clamp(petX + R(-300f, 300f), 26f * u, W - 14f * u);
        couchY = Clamp(petY + R(-200f, 200f), 14f * u, H - 4f * u);
        couch = 1; couchT = 0f; couchPop = 0f; couchTalkT = 8f; zzzAcc = 0f;
        Say(CouchGo, 2.5f);
    }
    void EndCouch(bool wake)
    {
        if (couch == 0) return;
        int was = couch;
        couch = 0; idleT = 0f; StopCouchSounds();
        float u = U;
        for (int i = 0; i < 14; i++)
        {
            Spark sp = new Spark();
            sp.x = couchX + R(-10f, 10f) * u; sp.y = couchY + R(-8f, 0f) * u; sp.vx = R(-120f, 120f); sp.vy = -R(20f, 140f);
            sp.max = sp.life = R(0.5f, 1f); sp.size = R(4f, 9f) * Ws; sp.c = Color.FromArgb(190, 190, 190); sp.gy = -30f;
            sparks.Add(sp);
        }
        if (wake && was >= 2)
        {
            panic = 2.5f; sq = 0.8f;
            petKX = R(-300f, 300f); petKY = R(-200f, 200f);
            Say(Pick(WakeP), 2f);
        }
    }

    void StartWork()
    {
        work = 1; workT = 0f; workTalkT = 4f; fleeing = false;
        Say(WorkStart, 2.5f);
        StartType(false);
    }
    void EndWork()
    {
        work = 0; streak = 0; StopType();
        Say(Pick(WorkEndP), 2.5f);
        petKX = R(-400f, 400f); petKY = R(-300f, 300f); sq = 0.6f;
    }

    void SpawnWorkFx(float dt)
    {
        float u = U; bool fr = work == 2;
        codeAcc += dt * (fr ? 14f : 2.5f);
        string[] sy = { "{ }", "</>", "01", "if", "for", "=>", ";", "//", "git", "fix", "bug!", "()" };
        while (codeAcc >= 1f)
        {
            codeAcc -= 1f;
            FText ft = new FText(); ft.sm = true;
            ft.x = petX + R(-6f, 6f) * u; ft.y = petY - 6f * u; ft.s = sy[rnd.Next(sy.Length)];
            ft.c = Color.FromArgb(120, 230, 140); ft.t = 0.3f; ft.rise = R(90f, 180f) * Ws;
            texts.Add(ft);
        }
        if (fr)
        {
            sweatAcc += dt * 9f;
            while (sweatAcc >= 1f)
            {
                sweatAcc -= 1f;
                Spark sw1 = new Spark();
                sw1.x = petX + R(-4f, 4f) * u; sw1.y = petY - 8.5f * u; sw1.vx = R(-160f, 160f) * Ws; sw1.vy = -R(120f, 300f) * Ws;
                sw1.max = sw1.life = R(0.4f, 0.7f); sw1.size = R(2f, 3.5f) * Ws; sw1.c = Color.FromArgb(140, 210, 255); sw1.gy = 900f;
                sparks.Add(sw1);
                Spark sm1 = new Spark();
                sm1.x = petX + R(-3f, 3f) * u; sm1.y = petY - 5.5f * u; sm1.vx = R(-30f, 30f); sm1.vy = -R(40f, 120f) * Ws;
                sm1.max = sm1.life = R(0.6f, 1.1f); sm1.size = R(3f, 6f) * Ws; sm1.c = Color.FromArgb(150, 150, 150); sm1.gy = -40f;
                sparks.Add(sm1);
            }
        }
    }

    static byte[] Chip(byte[] w)
    {
        if (w == null || w.Length < 44) return null;
        int ch = BitConverter.ToInt16(w, 22), sr = BitConverter.ToInt32(w, 24), bits = BitConverter.ToInt16(w, 34);
        if (BitConverter.ToInt16(w, 20) != 1 || bits != 16 || ch < 1) return null;
        int pos = 12, start = -1;
        while (pos + 8 <= w.Length)
        {
            string id = Encoding.ASCII.GetString(w, pos, 4);
            int size = BitConverter.ToInt32(w, pos + 4);
            if (id == "data") { start = pos + 8; break; }
            if (size < 0) break;
            pos += 8 + size + (size & 1);
        }
        if (start < 0) return null;
        int len = (w.Length - start) & ~1;
        if (len <= 0) return null;
        int nsr = (int)(sr * VoicePitch);
        MemoryStream ms = new MemoryStream();
        BinaryWriter bw = new BinaryWriter(ms);
        bw.Write(new char[] { 'R', 'I', 'F', 'F' }); bw.Write(36 + len);
        bw.Write(new char[] { 'W', 'A', 'V', 'E', 'f', 'm', 't', ' ' });
        bw.Write(16); bw.Write((short)1); bw.Write((short)ch); bw.Write(nsr); bw.Write(nsr * ch * 2); bw.Write((short)(ch * 2)); bw.Write((short)16);
        bw.Write(new char[] { 'd', 'a', 't', 'a' }); bw.Write(len);
        bw.Write(w, start, len);
        bw.Flush();
        return ms.ToArray();
    }

    // ----- ikony pulpitu (tylko nakladka - prawdziwe ikony nie sa ruszane)
    IntPtr FindDesktopList()
    {
        IntPtr prog = FindWindow("Progman", null);
        IntPtr def = prog == IntPtr.Zero ? IntPtr.Zero : FindWindowEx(prog, IntPtr.Zero, "SHELLDLL_DefView", null);
        if (def == IntPtr.Zero)
        {
            IntPtr found = IntPtr.Zero;
            EnumWindows(delegate (IntPtr h, IntPtr l)
            {
                IntPtr d = FindWindowEx(h, IntPtr.Zero, "SHELLDLL_DefView", null);
                if (d != IntPtr.Zero) { found = d; return false; }
                return true;
            }, IntPtr.Zero);
            def = found;
        }
        return def == IntPtr.Zero ? IntPtr.Zero : FindWindowEx(def, IntPtr.Zero, "SysListView32", null);
    }

    List<Rectangle> ScanIcons()
    {
        List<Rectangle> res = new List<Rectangle>();
        try
        {
            IntPtr lv = FindDesktopList();
            if (lv == IntPtr.Zero) return res;
            IntPtr r;
            if (SendMessageTimeout(lv, 0x1004, IntPtr.Zero, IntPtr.Zero, 2, 200, out r) == IntPtr.Zero) return res;
            int cnt = (int)r;
            if (cnt <= 0 || cnt > 500) return res;
            uint pid; GetWindowThreadProcessId(lv, out pid);
            IntPtr hp = OpenProcess(0x0038 | 0x0400, false, pid);
            if (hp == IntPtr.Zero) return res;
            IntPtr mem = VirtualAllocEx(hp, IntPtr.Zero, new UIntPtr(4096u), 0x3000, 4);
            if (mem == IntPtr.Zero) { CloseHandle(hp); return res; }
            try
            {
                POINT org = new POINT(); ClientToScreen(lv, ref org);
                byte[] zero = new byte[16]; byte[] buf = new byte[16]; IntPtr io;
                for (int i = 0; i < cnt; i++)
                {
                    WriteProcessMemory(hp, mem, zero, 16, out io);
                    if (SendMessageTimeout(lv, 0x100E, (IntPtr)i, mem, 2, 200, out r) == IntPtr.Zero) continue;
                    if (!ReadProcessMemory(hp, mem, buf, 16, out io)) continue;
                    int l = BitConverter.ToInt32(buf, 0), t = BitConverter.ToInt32(buf, 4), rr = BitConverter.ToInt32(buf, 8), b = BitConverter.ToInt32(buf, 12);
                    if (rr - l < 8 || b - t < 8 || rr - l > 600 || b - t > 600) continue;
                    res.Add(new Rectangle(org.X + l, org.Y + t, rr - l, b - t));
                }
            }
            finally { VirtualFreeEx(hp, mem, UIntPtr.Zero, 0x8000); CloseHandle(hp); }
        }
        catch (Exception) { }
        return res;
    }

    bool IconVisible(Rectangle r)
    {
        try
        {
            POINT pt = new POINT(); pt.X = r.X + r.Width / 2; pt.Y = r.Y + r.Height / 2;
            IntPtr h = WindowFromPoint(pt);
            if (h == IntPtr.Zero) return false;
            StringBuilder sb = new StringBuilder(64);
            GetClassName(h, sb, 64);
            return sb.ToString() == "SysListView32";
        }
        catch (Exception) { return false; }
    }

    string Pick(string[] a) { return a[rnd.Next(a.Length)]; }
    float AngleToPet() { return (float)Math.Atan2(petY - 5.5f * U - my, petX - mx); }

    // bez ruchu myszy: celuje w zwierzatko, a gdy jest poza zasiegiem - w najblizsza ikone
    float AimAuto()
    {
        float pcx = petX, pcy = petY - 5.5f * U;
        float dp = (float)Math.Sqrt((pcx - mx) * (pcx - mx) + (pcy - my) * (pcy - my));
        if (dp < LEN * 1.15f) return AngleToPet();
        float best = LEN * 1.2f, ba = 0f; bool found = false;
        for (int i = 0; i < curIcons.Count; i++)
        {
            Rectangle r = curIcons[i];
            float cx = r.X - VX + r.Width / 2f, cy = r.Y - VY + r.Height / 2f;
            float d = (float)Math.Sqrt((cx - mx) * (cx - mx) + (cy - my) * (cy - my));
            if (d > 60f * Ws && d < best) { best = d; ba = (float)Math.Atan2(cy - my, cx - mx); found = true; }
        }
        return found ? ba : AngleToPet();
    }

    // ------------------------------------------------------------ main loop
    int errs;
    void Tick(object sender, EventArgs ev)
    {
        try { TickInner(); }
        catch (Exception ex)
        {
            if (errs++ < 5)
            {
                try { File.AppendAllText(Path.Combine(Path.GetTempPath(), "C_Slave_PL_error.txt"), DateTime.Now + "\r\n" + ex + "\r\n\r\n"); } catch (Exception) { }
            }
            try { g.ResetTransform(); } catch (Exception) { }
        }
    }

    void TickInner()
    {
        if (quitReq) { timer.Stop(); Close(); return; }
        double now = sw.Elapsed.TotalSeconds;
        float dt = (float)Math.Min(0.05, now - last); last = now;
        if (dt <= 0f) return;
        T += dt; tick++;

        float ox = mx, oy = my;
        POINT p; GetCursorPos(out p); mx = p.X - VX; my = p.Y - VY;
        float kv = Math.Min(1f, dt * 10f);
        vxs += ((mx - ox) / dt - vxs) * kv; vys += ((my - oy) / dt - vys) * kv;
        if (!hintSaid) { lock (vfiles) { if (vfiles.ContainsKey(HintSpoken)) { hintSaid = true; } } if (hintSaid) PlayVoice(HintSpoken); }

        if (crackReq) { crackReq = false; StartCrack(); }
        if (crackT >= 0f)
        {
            float prev = crackT; crackT += dt;
            if (prev < 0.14f && crackT >= 0.14f && !aimLocked) aim = AimAuto();
            if (!crackDone && crackT >= 0.19f) { crackDone = true; DoCrack(); }
            if (crackT > 0.5f) crackT = -1f;
        }

        float acc = dt;
        while (acc > 1e-5f) { float h = Math.Min(acc, 1f / 120f); StepWhip(h); acc -= h; }

        for (int i = 0; i < N; i++)
        {
            if (float.IsNaN(wx[i]) || float.IsNaN(wy[i]) || float.IsInfinity(wx[i]) || float.IsInfinity(wy[i]))
            { for (int k = 0; k < N; k++) { wx[k] = wpx[k] = mx; wy[k] = wpy[k] = my + k * SEG; } break; }
        }
        UpdatePet(dt);
        UpdateFx(dt);
        PumpLoops(dt);
        Render();

        if (tick % 60 == 0) SetWindowPos(Handle, (IntPtr)(-1), 0, 0, 0, 0, 0x1 | 0x2 | 0x10);
    }

    void StartCrack()
    {
        if (crackT >= 0f) return;
        crackT = 0f; crackDone = false; idleT = 0f;
        curIcons = ScanIcons();
        float spd = (float)Math.Sqrt(vxs * vxs + vys * vys);
        if (spd > 250f * Ws) { aim = (float)Math.Atan2(vys, vxs); aimLocked = true; }
        else { aim = AimAuto(); aimLocked = false; }
        float a1 = aim + 2.4f, a2 = aim - 2.4f;
        windAng = Math.Sin(a1) < Math.Sin(a2) ? a1 : a2;
        PlayWhip();
    }

    void StepWhip(float h)
    {
        float grav = 1500f * h * h;
        float damp = (float)Math.Pow(0.996, h * 120.0);
        for (int i = 1; i < N; i++)
        {
            float vx = (wx[i] - wpx[i]) * damp, vy = (wy[i] - wpy[i]) * damp;
            wpx[i] = wx[i]; wpy[i] = wy[i];
            wx[i] += vx; wy[i] += vy + grav;
        }
        wx[0] = mx; wy[0] = my; wpx[0] = mx; wpy[0] = my;

        for (int i = 2; i < N; i++)
        {
            float dx = wx[i - 1] - wx[i - 2], dy = wy[i - 1] - wy[i - 2];
            float d = (float)Math.Sqrt(dx * dx + dy * dy);
            if (d > 0.001f)
            {
                dx /= d; dy /= d;
                float k = 0.35f * (float)Math.Pow(1.0 - (double)i / N, 1.5);
                wx[i] += (wx[i - 1] + dx * SEG - wx[i]) * k;
                wy[i] += (wy[i - 1] + dy * SEG - wy[i]) * k;
            }
        }

        if (crackT >= 0f)
        {
            if (crackT < 0.14f)
            {
                float cx = (float)Math.Cos(windAng), cy = (float)Math.Sin(windAng);
                for (int i = 3; i < N; i++)
                {
                    float w = 0.06f * i / (N - 1);
                    wx[i] += (mx + cx * SEG * i * 0.85f - wx[i]) * w;
                    wy[i] += (my + cy * SEG * i * 0.85f - wy[i]) * w;
                }
            }
            else if (crackT < 0.24f)
            {
                float cx = (float)Math.Cos(aim), cy = (float)Math.Sin(aim);
                for (int i = 3; i < N; i++)
                {
                    float w = 0.55f * (float)Math.Pow(i / (double)(N - 1), 0.6);
                    wx[i] += (mx + cx * SEG * i - wx[i]) * w;
                    wy[i] += (my + cy * SEG * i - wy[i]) * w;
                }
            }
        }

        for (int it = 0; it < 12; it++)
        {
            for (int i = 0; i < N - 1; i++)
            {
                float dx = wx[i + 1] - wx[i], dy = wy[i + 1] - wy[i];
                float d = (float)Math.Sqrt(dx * dx + dy * dy);
                if (d < 1e-4f) continue;
                float diff = (d - SEG) / d;
                if (i == 0) { wx[1] -= dx * diff; wy[1] -= dy * diff; }
                else
                {
                    wx[i] += dx * diff * 0.5f; wy[i] += dy * diff * 0.5f;
                    wx[i + 1] -= dx * diff * 0.5f; wy[i + 1] -= dy * diff * 0.5f;
                }
            }
        }
        for (int i = 1; i < N; i++) if (wy[i] > H - 2) wy[i] = H - 2;
    }

    void DoCrack()
    {
        float tx = wx[N - 1], ty = wy[N - 1];
        for (int i = 0; i < 28; i++)
        {
            Spark s = new Spark();
            float a = R(0f, 6.2832f), sp = R(150f, 650f);
            s.x = tx; s.y = ty; s.vx = (float)Math.Cos(a) * sp; s.vy = (float)Math.Sin(a) * sp;
            s.max = s.life = R(0.3f, 0.7f); s.size = R(2f, 5f) * Ws;
            int k = rnd.Next(3);
            s.c = k == 0 ? Color.FromArgb(255, 255, 240) : (k == 1 ? Color.FromArgb(255, 205, 70) : Color.FromArgb(255, 130, 50));
            sparks.Add(s);
        }
        Ring r = new Ring(); r.x = tx; r.y = ty; rings.Add(r);
        FText ft = new FText(); ft.x = tx; ft.y = ty - 20; ft.s = "TRZASK!"; ft.c = Color.FromArgb(255, 225, 90); texts.Add(ft);
        Mark m = new Mark(); m.x = tx; m.y = ty; marks.Add(m);
        shake = 9f;

        int smashed = 0;
        for (int i = 0; i < curIcons.Count && smashed < 10 && smashes.Count < 16; i++)
        {
            Rectangle ir = curIcons[i];
            float icx = ir.X - VX + ir.Width / 2f, icy = ir.Y - VY + ir.Height / 2f;
            float ds = DistSeg(icx, icy, mx, my, tx, ty);
            if (ds > 35f * Ws + 0.35f * Math.Max(ir.Width, ir.Height)) continue;
            bool dup = false;
            for (int k = 0; k < smashes.Count; k++) if (Math.Abs(smashes[k].r.X - ir.X) < 8 && Math.Abs(smashes[k].r.Y - ir.Y) < 8) dup = true;
            if (dup || !IconVisible(ir)) continue;
            MakeSmash(ir, tx, ty); smashed++;
        }

        float ex = mx + (float)Math.Cos(aim) * LEN, ey = my + (float)Math.Sin(aim) * LEN;
        float pcx = petX, pcy = petY - 5.5f * U;
        float dd = DistSeg(pcx, pcy, mx, my, ex, ey);
        float dTip = (float)Math.Sqrt((pcx - tx) * (pcx - tx) + (pcy - ty) * (pcy - ty));
        if (dd < 10f * U) HitPet();
        else if (couch > 0) EndCouch(true);
        else if (dTip < 260f * U / 6f || dd < 150f * U / 6f)
        {
            panic = Math.Max(panic, 2.5f);
            if (bubT < 1.2f) Say(Pick(ScareP), 1.3f);
        }
    }

    void MakeSmash(Rectangle r, float ix, float iy)
    {
        try
        {
            int m = 4;
            Rectangle q = new Rectangle(r.X - m, r.Y - m, r.Width + 2 * m, r.Height + 2 * m);
            Bitmap cap = new Bitmap(q.Width, q.Height, PixelFormat.Format32bppArgb);
            using (Graphics cg = Graphics.FromImage(cap)) cg.CopyFromScreen(q.X, q.Y, 0, 0, q.Size);
            // zaslona: kazdy wiersz plynnie miedzy kolorem tla z lewej i z prawej strony ikony
            Bitmap cover = new Bitmap(r.Width, r.Height, PixelFormat.Format32bppArgb);
            for (int y = 0; y < r.Height; y++)
            {
                Color a = cap.GetPixel(1, y + m), b = cap.GetPixel(q.Width - 2, y + m);
                for (int x = 0; x < r.Width; x++)
                {
                    float t = x / (float)Math.Max(1, r.Width - 1);
                    cover.SetPixel(x, y, Color.FromArgb(255, (int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t)));
                }
            }
            Smash sm = new Smash(); sm.r = r; sm.cap = cap; sm.cover = cover;
            int fs = Math.Max(12, (int)(16 * Ws));
            for (int yy = 0; yy < r.Height; yy += fs)
                for (int xx = 0; xx < r.Width; xx += fs)
                {
                    Frag f = new Frag();
                    int w = Math.Min(fs, r.Width - xx), h = Math.Min(fs, r.Height - yy);
                    f.src = new Rectangle(m + xx, m + yy, w, h);
                    f.x = r.X - VX + xx + w / 2f; f.y = r.Y - VY + yy + h / 2f;
                    float dx = f.x - ix, dy = f.y - iy; float dl = (float)Math.Sqrt(dx * dx + dy * dy); if (dl < 1f) dl = 1f;
                    float sp = R(180f, 520f) * Ws;
                    f.vx = dx / dl * sp + R(-80f, 80f); f.vy = dy / dl * sp - R(80f, 260f) * Ws; f.av = R(-10f, 10f);
                    sm.frags.Add(f);
                }
            smashes.Add(sm);
            float cx = r.X - VX + r.Width / 2f, cy = r.Y - VY + r.Height / 2f;
            for (int i = 0; i < 12; i++)
            {
                Spark s = new Spark();
                float a = R(0f, 6.2832f), sp = R(60f, 260f);
                s.x = cx; s.y = cy; s.vx = (float)Math.Cos(a) * sp; s.vy = (float)Math.Sin(a) * sp;
                s.max = s.life = R(0.4f, 0.9f); s.size = R(3f, 7f) * Ws; s.c = Color.FromArgb(200, 200, 200);
                sparks.Add(s);
            }
        }
        catch (Exception) { }
    }

    void HitPet()
    {
        hits++;
        streak++; lastHitT = T; idleT = 0f;
        if (couch > 0) EndCouch(false);
        if (work > 0) { petKX = 0f; petKY = 0f; panic = 0f; dizzy = 0f; sq = 0.5f; Say(Pick(WorkHitP), 1.6f); }
        else
        {
            petKX = (float)Math.Cos(aim) * 1100f * U / 6f; petKY = (float)Math.Sin(aim) * 1100f * U / 6f;
            panic = 3.5f; dizzy = 1.0f; sq = 1f;
            Say(Pick(HitP), 2f);
        }
        float pcx = petX, pcy = petY - 5.5f * U;
        for (int i = 0; i < 14; i++)
        {
            Spark s = new Spark();
            float a = R(0f, 6.2832f), sp = R(100f, 420f);
            s.x = pcx; s.y = pcy; s.vx = (float)Math.Cos(a) * sp; s.vy = (float)Math.Sin(a) * sp - 120f;
            s.max = s.life = R(0.4f, 0.8f); s.size = R(2.5f, 5f) * Ws;
            s.c = Color.FromArgb(255, 217, 119, 87);
            sparks.Add(s);
        }
        FText ft = new FText(); ft.x = pcx; ft.y = pcy - 6f * U; ft.s = "-1 token"; ft.c = Color.FromArgb(255, 255, 140, 120); texts.Add(ft);
    }

    // ------------------------------------------------------------ pet logic
    void UpdatePet(float dt)
    {
        float k = U / 6f;
        if (couch > 0)
        {
            couchT += dt; couchPop += dt;
            petKX = 0f; petKY = 0f;
            if (couch == 1)
            {
                float ddx = couchX - petX, ddy = couchY - petY;
                float dl = (float)Math.Sqrt(ddx * ddx + ddy * ddy);
                float spd1 = 100f * k;
                if (dl > 8f && couchT < 25f)
                {
                    petVX = ddx / dl * spd1; petVY = ddy / dl * spd1;
                    petX += petVX * dt; petY += petVY * dt;
                    petPhase += dt * (6f + spd1 * 0.03f);
                }
                else
                {
                    petX = couchX; petY = couchY; petVX = 0f; petVY = 0f;
                    couch = 2; couchT = 0f; couchTalkT = 8f; sq = 0.3f;
                    Say(TvOn, 2.5f);
                    StartLoop("pejczx", "#tvon", false); StartLoop("pejczt", "#tv", true);
                }
            }
            else
            {
                petVX = 0f; petVY = 0f;
                if (couch == 2)
                {
                    couchTalkT -= dt;
                    if (couchTalkT <= 0f && bubT <= 0.2f) { Say(Pick(ReadP), 2.5f); couchTalkT = R(9f, 15f); }
                    if (couchT > ReadFor)
                    {
                        couch = 3; couchT = 0f; zzzAcc = 0f;
                        Say(SleepLine, 3f);
                        try { mciSendString("close pejczx", null, 0, IntPtr.Zero); } catch (Exception) { }
                        StartLoop("pejczs", "#snore", true);
                    }
                }
                else
                {
                    zzzAcc += dt;
                    if (zzzAcc >= 1.1f)
                    {
                        zzzAcc = 0f;
                        FText z = new FText(); z.s = rnd.Next(3) == 0 ? "Zzz" : "Z"; z.c = Color.FromArgb(180, 205, 255);
                        if (bubT <= 0.2f && rnd.Next(2) == 0) Say("Chrrr... pfff...", 1.6f, "");
                        z.x = petX + 4f * U; z.y = petY - 9f * U; z.rise = R(35f, 55f) * Ws; texts.Add(z);
                    }
                }
            }
            panic = 0f; dizzy -= dt; sq = Math.Max(0f, sq - dt * 4f); bubT -= dt;
            blinkT -= dt; if (blinkT < -0.12f) blinkT = R(2f, 5f);
            return;
        }
        if (work == 0)
        {
            if (streak >= 4 && dizzy <= 0f && Math.Abs(petKX) + Math.Abs(petKY) < 40f) StartWork();
        }
        else
        {
            workT += dt;
            if (work == 1 && streak >= 7) { work = 2; Say(Pick(FrenzyStartP), 2.5f); StartType(true); }
            if (T - lastHitT > 12f) EndWork();
        }
        if (work > 0)
        {
            petVX = 0f; petVY = 0f; petKX = 0f; petKY = 0f; fleeing = false;
            dizzy -= dt; panic = 0f; sq = Math.Max(0f, sq - dt * 4f); bubT -= dt;
            blinkT -= dt; if (blinkT < -0.12f) blinkT = R(2f, 5f);
            workTalkT -= dt;
            if (workTalkT <= 0f && bubT <= 0.2f) { Say(Pick(work == 2 ? FrenzyP : WorkP), 2.2f); workTalkT = R(3.5f, 5.5f); }
            SpawnWorkFx(dt);
            return;
        }
        float cx = petX, cy = petY - 5.5f * U;
        float dx = cx - mx, dy = cy - my;
        float d = (float)Math.Sqrt(dx * dx + dy * dy); if (d < 1f) d = 1f;
        float Rr = (panic > 0f ? 380f : 230f) * k;
        float tvx = 0f, tvy = 0f;
        float minX = 8f * U, maxX = W - 8f * U, minY = 12f * U, maxY = H - U;

        sideT -= dt;
        if (dizzy > 0f) { }
        else if (d < Rr)
        {
            if (!fleeing) { fleeing = true; if (bubT <= 0f && rnd.NextDouble() < 0.5) Say(Pick(FleeP), 1.4f); }
            float ax = dx / d, ay = dy / d;
            float m = 120f * k;
            if (petX < m) ax += (m - petX) / m * 1.8f;
            if (petX > W - m) ax -= (petX - (W - m)) / m * 1.8f;
            if (petY < m + 60f) ay += (m + 60f - petY) / m * 1.8f;
            if (petY > H - m) ay -= (petY - (H - m)) / m * 1.8f;
            float l = (float)Math.Sqrt(ax * ax + ay * ay); if (l < 1e-4f) l = 1f;
            ax /= l; ay /= l;
            // lekki unik na bok, zeby nie uciekal tylko po prostej
            if (sideT <= 0f) { petSide = rnd.NextDouble() < 0.5 ? 1f : -1f; petSideW = R(0.3f, 1.3f); sideT = R(0.5f, 1.5f); }
            float nx = ax - ay * petSide * petSideW, ny = ay + ax * petSide * petSideW;
            l = (float)Math.Sqrt(nx * nx + ny * ny); if (l < 1e-4f) l = 1f;
            nx /= l; ny /= l;
            float sp = (150f + (Rr - d) * 1.6f) * k * (panic > 0f ? 1.5f : 1f);
            tvx = nx * sp; tvy = ny * sp;
        }
        else
        {
            fleeing = false;
            petWT -= dt;
            float ddx = petTX - petX, ddy = petTY - petY;
            float dl = (float)Math.Sqrt(ddx * ddx + ddy * ddy);
            if (petWT <= 0f)
            {
                if (dl <= 10f && rnd.NextDouble() < 0.3) petWT = R(1f, 3f);
                else
                {
                    // losowy kierunek i dystans; przy scianie kierunek odbija sie do wnetrza
                    float wa = R(0f, 6.2832f), wd = R(150f, 450f) * k;
                    petTX = Clamp(petX + (float)Math.Cos(wa) * wd, minX, maxX);
                    petTY = Clamp(petY + (float)Math.Sin(wa) * wd, minY, maxY);
                    petWSpd = R(55f, 115f);
                    petWT = R(2f, 5f);
                    ddx = petTX - petX; ddy = petTY - petY;
                    dl = (float)Math.Sqrt(ddx * ddx + ddy * ddy);
                }
            }
            if (dl > 10f) { tvx = ddx / dl * petWSpd * k; tvy = ddy / dl * petWSpd * k; }
        }
        float lerp = Math.Min(1f, dt * 6f);
        petVX += (tvx - petVX) * lerp; petVY += (tvy - petVY) * lerp;
        petX += (petVX + petKX) * dt; petY += (petVY + petKY) * dt;
        float kd = (float)Math.Exp(-dt * 3.5);
        petKX *= kd; petKY *= kd;

        if (fleeing || panic > 0f || dizzy > 0f) idleT = 0f; else idleT += dt;
        if (idleT >= CouchAfter && work == 0) StartCouch();
        bool clamped = false;
        if (petX < minX) { petX = minX; clamped = true; petKX = Math.Abs(petKX) * 0.4f; }
        if (petX > maxX) { petX = maxX; clamped = true; petKX = -Math.Abs(petKX) * 0.4f; }
        if (petY < minY) { petY = minY; clamped = true; petKY = Math.Abs(petKY) * 0.4f; }
        if (petY > maxY) { petY = maxY; clamped = true; petKY = -Math.Abs(petKY) * 0.4f; }
        if (clamped && sideT <= 0f) { petSide = rnd.NextDouble() < 0.5 ? 1f : -1f; sideT = 0.8f; }

        float spd = (float)Math.Sqrt(petVX * petVX + petVY * petVY);
        petPhase += dt * (6f + spd * 0.03f);
        panic -= dt; dizzy -= dt; sq = Math.Max(0f, sq - dt * 4f); bubT -= dt;
        blinkT -= dt; if (blinkT < -0.12f) blinkT = R(2f, 5f);
    }

    void UpdateFx(float dt)
    {
        for (int i = sparks.Count - 1; i >= 0; i--)
        {
            Spark s = sparks[i]; s.life -= dt;
            if (s.life <= 0f) { sparks.RemoveAt(i); continue; }
            s.x += s.vx * dt; s.y += s.vy * dt; s.vy += s.gy * dt; s.vx *= Math.Max(0f, 1f - 3f * dt);
        }
        for (int i = rings.Count - 1; i >= 0; i--) { rings[i].t += dt; if (rings[i].t > 0.35f) rings.RemoveAt(i); }
        for (int i = texts.Count - 1; i >= 0; i--) { texts[i].t += dt; texts[i].y -= texts[i].rise * dt; if (texts[i].t > 1f) texts.RemoveAt(i); }
        for (int i = marks.Count - 1; i >= 0; i--) { marks[i].t += dt; if (marks[i].t > 4f) marks.RemoveAt(i); }
        for (int i = smashes.Count - 1; i >= 0; i--)
        {
            Smash sm = smashes[i]; sm.t += dt;
            for (int k = 0; k < sm.frags.Count; k++)
            {
                Frag f = sm.frags[k];
                f.x += f.vx * dt; f.y += f.vy * dt; f.vy += 900f * dt; f.ang += f.av * dt;
            }
            if (sm.t > 4.0f) { sm.cap.Dispose(); sm.cover.Dispose(); smashes.RemoveAt(i); }
        }
        shake = Math.Max(0f, shake - dt * 40f);
    }

    // ------------------------------------------------------------ render
    void Render()
    {
        g.ResetTransform();
        g.Clear(Color.Transparent);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        if (shake > 0f) g.TranslateTransform((float)(rnd.NextDouble() - 0.5) * shake, (float)(rnd.NextDouble() - 0.5) * shake);

        DrawMarks();
        DrawSmashes();
        if (couch > 0) DrawCouchBack();
        DrawPet();
        if (couch >= 2) DrawCouchFront();
        DrawWhip();
        DrawFx();
        DrawBubble();
        g.ResetTransform();

        POINT pd = new POINT(); pd.X = VX; pd.Y = VY;
        SIZE sz = new SIZE(); sz.cx = W; sz.cy = H;
        POINT ps = new POINT();
        BLEND bl = new BLEND(); bl.Op = 0; bl.Flags = 0; bl.Alpha = 255; bl.Format = 1;
        UpdateLayeredWindow(Handle, screenDC, ref pd, ref sz, memDC, ref ps, 0, ref bl, 2);
    }

    static ImageAttributes AlphaAttr(float a)
    {
        ColorMatrix cm = new ColorMatrix(); cm.Matrix33 = Clamp(a, 0f, 1f);
        ImageAttributes ia = new ImageAttributes(); ia.SetColorMatrix(cm);
        return ia;
    }

    void DrawSmashes()
    {
        for (int i = 0; i < smashes.Count; i++)
        {
            Smash sm = smashes[i];
            float ca = sm.t < 3.5f ? 1f : 1f - (sm.t - 3.5f) / 0.5f;
            using (ImageAttributes ia = AlphaAttr(ca))
                g.DrawImage(sm.cover, new Rectangle(sm.r.X - VX, sm.r.Y - VY, sm.r.Width, sm.r.Height), 0, 0, sm.r.Width, sm.r.Height, GraphicsUnit.Pixel, ia);
            if (sm.t >= 1.7f) continue;
            float fa = sm.t < 1.2f ? 1f : 1f - (sm.t - 1.2f) / 0.5f;
            using (ImageAttributes ia = AlphaAttr(fa))
            {
                for (int k = 0; k < sm.frags.Count; k++)
                {
                    Frag f = sm.frags[k];
                    GraphicsState st = g.Save();
                    g.TranslateTransform(f.x, f.y);
                    g.RotateTransform(f.ang * 57.3f);
                    g.DrawImage(sm.cap, new Rectangle(-f.src.Width / 2, -f.src.Height / 2, f.src.Width, f.src.Height), f.src.X, f.src.Y, f.src.Width, f.src.Height, GraphicsUnit.Pixel, ia);
                    g.Restore(st);
                }
            }
        }
    }

    void DrawMarks()
    {
        for (int i = 0; i < marks.Count; i++)
        {
            Mark m = marks[i]; float a = 1f - m.t / 4f;
            using (Pen p = new Pen(Color.FromArgb(A(a * 0.5f), 30, 20, 15), 2f * Ws))
            {
                float r = 9f * Ws;
                g.DrawLine(p, m.x - r, m.y - r, m.x + r, m.y + r);
                g.DrawLine(p, m.x + r, m.y - r, m.x - r, m.y + r);
                g.DrawLine(p, m.x - r * 1.3f, m.y, m.x + r * 1.3f, m.y);
            }
        }
    }

    void DrawWhip()
    {
        // glow podczas uderzenia
        if (crackT >= 0.12f && crackT < 0.3f)
        {
            PointF[] st = new PointF[N - N / 2];
            for (int i = N / 2; i < N; i++) st[i - N / 2] = new PointF(wx[i], wy[i]);
            using (Pen p = new Pen(Color.FromArgb(120, 255, 255, 255), 7f * Ws)) { p.LineJoin = LineJoin.Round; p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLines(p, st); }
        }
        // plecionka
        for (int i = 3; i < N - 1; i++)
        {
            float t = i / (float)(N - 1);
            float w = (6.5f - 4.8f * t) * Ws;
            Color c = (i % 2 == 0) ? Color.FromArgb(255, 132, 78, 38) : Color.FromArgb(255, 92, 52, 24);
            using (Pen p = new Pen(c, w)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLine(p, wx[i], wy[i], wx[i + 1], wy[i + 1]); }
        }
        PointF[] pts = new PointF[N - 3];
        for (int i = 3; i < N; i++) pts[i - 3] = new PointF(wx[i], wy[i]);
        using (Pen hl = new Pen(Color.FromArgb(80, 255, 210, 150), 1.2f * Ws)) { hl.LineJoin = LineJoin.Round; g.DrawLines(hl, pts); }

        // popper na koncu
        float tx = wx[N - 1], ty = wy[N - 1];
        using (Pen fp = new Pen(Color.FromArgb(230, 235, 215, 170), 1.3f * Ws))
        {
            for (int i = 0; i < 3; i++)
            {
                float a = R(0f, 6.2832f), l = R(5f, 11f) * Ws;
                g.DrawLine(fp, tx, ty, tx + (float)Math.Cos(a) * l, ty + (float)Math.Sin(a) * l);
            }
        }

        // raczka (hotspot kursora w punkcie 0)
        for (int i = 0; i < 3; i++)
        {
            using (Pen p = new Pen(Color.FromArgb(255, 52, 32, 20), 9f * Ws)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLine(p, wx[i], wy[i], wx[i + 1], wy[i + 1]); }
            using (Pen p = new Pen(Color.FromArgb(120, 190, 130, 80), 1.5f * Ws)) { g.DrawLine(p, wx[i], wy[i], wx[i + 1], wy[i + 1]); }
        }
        using (SolidBrush b = new SolidBrush(Color.FromArgb(255, 212, 170, 60)))
        using (Pen o = new Pen(Color.FromArgb(255, 90, 60, 15), 1.5f))
        {
            float r1 = 5.5f * Ws, r2 = 4.5f * Ws;
            g.FillEllipse(b, wx[0] - r1, wy[0] - r1, r1 * 2, r1 * 2); g.DrawEllipse(o, wx[0] - r1, wy[0] - r1, r1 * 2, r1 * 2);
            g.FillEllipse(b, wx[3] - r2, wy[3] - r2, r2 * 2, r2 * 2); g.DrawEllipse(o, wx[3] - r2, wy[3] - r2, r2 * 2, r2 * 2);
        }
    }

    void FillR(Brush b, float x, float y, float w, float h) { g.FillRectangle(b, x, y, w, h); }

    void DrawPet()
    {
        float u = U;
        float spd = (float)Math.Sqrt(petVX * petVX + petVY * petVY);
        bool moving = spd > 25f;
        bool cs = couch >= 2;
        bool wk = work > 0;
        float sit = wk ? 1.2f * u * Math.Min(1f, workT * 4f) : 0f;
        float bob = cs ? CouchBob(u) : wk ? -sit + (work == 2 ? (float)Math.Abs(Math.Sin(T * 40.0)) * u * 0.35f : (float)Math.Sin(T * 12.0) * u * 0.1f)
            : (moving ? Math.Abs((float)Math.Sin(petPhase)) * u * 0.5f : (float)Math.Sin(T * 2.5f) * u * 0.12f);
        float sx = 1f + sq * 0.35f, sy = 1f - sq * 0.35f;
        float tilt = Clamp(petVX * 0.0007f, -0.25f, 0.25f) + (dizzy > 0f ? (float)Math.Sin(T * 22f) * 0.14f : 0f);
        if (wk) tilt = 0f;
        if (cs) tilt = couch == 3 ? (float)Math.Sin(T * 1.2) * 0.09f - 0.05f : 0f;
        float jx = (wk && work == 2) ? ((float)rnd.NextDouble() - 0.5f) * u * 0.3f : 0f;

        using (SolidBrush sh = new SolidBrush(Color.FromArgb(70, 0, 0, 0))) g.FillEllipse(sh, petX - 6f * u, petY - 1.2f * u, 12f * u, 2.4f * u);

        GraphicsState st = g.Save();
        g.TranslateTransform(petX + jx, petY);
        g.RotateTransform(tilt * 57.3f);
        g.ScaleTransform(sx, sy);

        float legH = 2f * u;
        using (SolidBrush body = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (SolidBrush dark = new SolidBrush(Color.FromArgb(255, 176, 86, 58)))
        using (SolidBrush black = new SolidBrush(Color.FromArgb(255, 25, 20, 18)))
        {
            float[] lx = { -4.8f, -2.4f, 1.0f, 3.4f };
            for (int k = 0; k < 4; k++)
            {
                float lift = 0f;
                if (moving) lift = Math.Max(0f, (float)Math.Sin(petPhase * 2f + (k % 2) * Math.PI)) * u * 1.1f;
                FillR(dark, lx[k] * u, -legH + lift, 1.4f * u, legH - lift);
            }
            float armUp = panic > 0f ? u * 2.2f * (0.5f + 0.5f * (float)Math.Sin(T * 18f)) : 0f;
            if (!wk && !cs) { FillR(body, -8f * u, -legH - 4.6f * u - bob - armUp, 2f * u, 2f * u); FillR(body, 6f * u, -legH - 4.6f * u - bob - armUp, 2f * u, 2f * u); }
            FillR(body, -6f * u, -legH - 7f * u - bob, 12f * u, 7f * u);
            FillR(dark, -6f * u, -legH - 1.2f * u - bob, 12f * u, 1.2f * u);

            float ey = -legH - 5.7f * u - bob + (wk ? 0.5f * u : 0f);
            float exo = (cs && couch == 2) ? -0.6f * u : 0f;
            if (dizzy > 0f)
            {
                using (Pen p = new Pen(Color.FromArgb(255, 25, 20, 18), 0.5f * u))
                {
                    float[] ex = { -3.4f, 2.1f };
                    for (int k = 0; k < 2; k++)
                    {
                        float x0 = ex[k] * u, y0 = ey, w = 1.4f * u, h = 2.1f * u;
                        g.DrawLine(p, x0, y0, x0 + w, y0 + h); g.DrawLine(p, x0 + w, y0, x0, y0 + h);
                    }
                }
            }
            else if ((blinkT < 0f && work != 2) || (cs && couch == 3))
            {
                FillR(black, -3.4f * u, ey + 0.85f * u, 1.3f * u, 0.4f * u);
                FillR(black, 2.1f * u, ey + 0.85f * u, 1.3f * u, 0.4f * u);
            }
            else
            {
                FillR(black, -3.4f * u + exo, ey, 1.3f * u, 2.1f * u);
                FillR(black, 2.1f * u + exo, ey, 1.3f * u, 2.1f * u);
            }
        }
        g.Restore(st);
        if (wk) DrawDesk();

        if (dizzy > 0f)
        {
            using (SolidBrush y = new SolidBrush(Color.FromArgb(255, 255, 220, 60)))
            {
                for (int k = 0; k < 3; k++)
                {
                    float a = T * 7f + k * 2.094f;
                    float sxp = petX + (float)Math.Cos(a) * 5f * u, syp = petY - 10.5f * u + (float)Math.Sin(a) * 1.2f * u;
                    float r = 0.8f * u;
                    g.FillEllipse(y, sxp - r, syp - r, r * 2f, r * 2f);
                }
            }
        }
    }

    float CouchBob(float u)
    {
        if (couch == 3) return -0.9f * u + (float)Math.Sin(T * 1.6) * u * 0.15f;
        return -0.9f * u * Math.Min(1f, couchT * 3f);
    }

    void DrawTv(float u, bool on)
    {
        float sx0 = -22.2f * u, sy0 = -8.7f * u, sw = 10.4f * u, sh = 5.4f * u;
        Color[] pal = { Color.FromArgb(60, 110, 200), Color.FromArgb(200, 90, 60), Color.FromArgb(70, 160, 110), Color.FromArgb(150, 90, 190), Color.FromArgb(200, 180, 70) };
        int ph = (int)(T * 3.5f) % 5;
        if (on)
        {
            using (GraphicsPath gp = new GraphicsPath())
            {
                gp.AddEllipse(-33f * u, -16f * u, 30f * u, 22f * u);
                using (PathGradientBrush pg = new PathGradientBrush(gp))
                {
                    pg.CenterColor = Color.FromArgb((int)(70 + 30 * Math.Sin(T * 9)), pal[ph].R, pal[ph].G, pal[ph].B);
                    pg.SurroundColors = new Color[] { Color.FromArgb(0, pal[ph].R, pal[ph].G, pal[ph].B) };
                    g.FillPath(pg, gp);
                }
            }
        }
        using (SolidBrush fr = new SolidBrush(Color.FromArgb(255, 30, 30, 36)))
        {
            FillR(fr, -23f * u, -9.5f * u, 12f * u, 7f * u);
            FillR(fr, -19f * u, -2.5f * u, 4f * u, 1.4f * u);
            FillR(fr, -21f * u, -1.2f * u, 8f * u, 0.9f * u);
        }
        if (!on)
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(255, 20, 24, 30))) FillR(b, sx0, sy0, sw, sh);
            return;
        }
        using (SolidBrush b = new SolidBrush(pal[ph])) FillR(b, sx0, sy0, sw, sh);
        float mxp = sx0 + (float)((Math.Sin(T * 1.7) + 1.0) * 0.5) * (sw - 2.5f * u);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(200, 255, 255, 255))) g.FillEllipse(b, mxp, sy0 + 1.2f * u, 2.2f * u, 2.2f * u);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(220, 20, 20, 20))) FillR(b, sx0, sy0 + sh - 1.1f * u, sw, 1.1f * u);
        using (SolidBrush b = new SolidBrush(Color.FromArgb(255, 240, 240, 240)))
        {
            for (int k = 0; k < 6; k++)
            {
                float xx = sx0 + ((k * 1.9f * u + T * 3f * u) % (sw - 1.2f * u));
                FillR(b, xx, sy0 + sh - 0.8f * u, 1.2f * u, 0.4f * u);
            }
        }
        using (Pen p = new Pen(Color.FromArgb(40, 0, 0, 0), 1f))
        {
            for (float yy = sy0; yy < sy0 + sh; yy += 3f) g.DrawLine(p, sx0, yy, sx0 + sw, yy);
        }
        if (couch == 2 && couchT < 0.4f)
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(A(1f - couchT / 0.4f), 255, 255, 255))) FillR(b, sx0, sy0, sw, sh);
        }
    }

    void DrawCouchBack()
    {
        float u = U;
        float e = Math.Min(1f, couchPop / 0.4f);
        float sc = Math.Max(0.05f, e * (1f + 0.15f * (float)Math.Sin(e * Math.PI)));
        GraphicsState st = g.Save();
        g.TranslateTransform(couchX, couchY);
        g.ScaleTransform(sc, sc);
        DrawTv(u, couch >= 2);
        using (SolidBrush back = new SolidBrush(Color.FromArgb(255, 109, 47, 53)))
        using (SolidBrush roll = new SolidBrush(Color.FromArgb(255, 138, 61, 69)))
        using (SolidBrush leg = new SolidBrush(Color.FromArgb(255, 50, 32, 24)))
        using (SolidBrush cush = new SolidBrush(Color.FromArgb(255, 154, 70, 80)))
        using (SolidBrush arm = new SolidBrush(Color.FromArgb(255, 125, 54, 64)))
        {
            FillR(back, -10.5f * u, -11f * u, 21f * u, 8.5f * u);
            FillR(roll, -10.5f * u, -11.5f * u, 21f * u, 2f * u);
            FillR(leg, -11.5f * u, 0.2f * u, 1f * u, 0.9f * u);
            FillR(leg, 10.5f * u, 0.2f * u, 1f * u, 0.9f * u);
            if (couch == 1)
            {
                FillR(cush, -10f * u, -3.4f * u, 20f * u, 3.6f * u);
                FillR(arm, -12.5f * u, -6.5f * u, 2.6f * u, 7.2f * u);
                FillR(arm, 9.9f * u, -6.5f * u, 2.6f * u, 7.2f * u);
            }
        }
        g.Restore(st);
    }

    void DrawCouchFront()
    {
        float u = U;
        GraphicsState st = g.Save();
        g.TranslateTransform(couchX, couchY);
        using (SolidBrush cush = new SolidBrush(Color.FromArgb(255, 154, 70, 80)))
        using (SolidBrush arm = new SolidBrush(Color.FromArgb(255, 125, 54, 64)))
        using (SolidBrush skin = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (SolidBrush paper = new SolidBrush(Color.FromArgb(255, 239, 233, 214)))
        using (SolidBrush ink = new SolidBrush(Color.FromArgb(255, 45, 40, 34)))
        using (Pen seam = new Pen(Color.FromArgb(120, 60, 20, 26), 0.25f * u))
        {
            FillR(cush, -10f * u, -3.4f * u, 20f * u, 3.6f * u);
            g.DrawLine(seam, 0f, -3.4f * u, 0f, 0.2f * u);
            FillR(arm, -12.5f * u, -6.5f * u, 2.6f * u, 7.2f * u);
            FillR(arm, 9.9f * u, -6.5f * u, 2.6f * u, 7.2f * u);
            if (couch == 2)
            {
                float pf = T % 9f;
                float fx = pf < 0.4f ? Math.Max(0.03f, Math.Abs((float)Math.Cos(Math.PI * pf / 0.4f))) : 1f;
                GraphicsState s2 = g.Save();
                g.TranslateTransform(0f, -2.3f * u);
                g.ScaleTransform(fx, 1f);
                FillR(paper, -4.2f * u, -2.1f * u, 8.4f * u, 4.2f * u);
                FillR(ink, -3.8f * u, -1.8f * u, 7.6f * u, 0.8f * u);
                for (int i = 0; i < 4; i++)
                {
                    FillR(ink, -3.8f * u, (-0.5f + i * 0.65f) * u, (i % 2 == 0 ? 3.4f : 3.0f) * u, 0.22f * u);
                    FillR(ink, 0.3f * u, (-0.5f + i * 0.65f) * u, 3.4f * u, 0.22f * u);
                }
                g.Restore(s2);
                FillR(skin, -5.8f * u, -3.4f * u, 1.6f * u, 1.6f * u);
                FillR(skin, 4.2f * u, -3.4f * u, 1.6f * u, 1.6f * u);
            }
            else
            {
                float drop = (1f - Math.Min(1f, couchT / 0.6f)) * -2.2f * u;
                GraphicsState s2 = g.Save();
                g.TranslateTransform(0f, -1.4f * u + drop);
                g.RotateTransform(10f);
                FillR(paper, -3.5f * u, -1.1f * u, 7f * u, 2.2f * u);
                FillR(ink, -3.1f * u, -0.8f * u, 6.2f * u, 0.5f * u);
                FillR(ink, -3.1f * u, 0.1f * u, 4.0f * u, 0.2f * u);
                g.Restore(s2);
                FillR(skin, -7.6f * u, -2.2f * u, 1.6f * u, 1.6f * u);
                FillR(skin, 6.0f * u, -2.2f * u, 1.6f * u, 1.6f * u);
            }
        }
        g.Restore(st);
    }

    void DrawDesk()
    {
        float u = U; bool fr = work == 2;
        float e = Math.Min(1f, workT / 0.35f);
        float sc = Math.Max(0.05f, e * (1f + 0.2f * (float)Math.Sin(e * Math.PI)));
        float spd = fr ? 38f : 14f;
        GraphicsState st = g.Save();
        g.TranslateTransform(petX, petY);
        g.ScaleTransform(sc, sc);
        using (SolidBrush wood = new SolidBrush(Color.FromArgb(255, 130, 88, 52)))
        using (SolidBrush woodD = new SolidBrush(Color.FromArgb(255, 88, 56, 32)))
        using (SolidBrush lapBack = new SolidBrush(fr ? Color.FromArgb(255, 170, 70, 50) : Color.FromArgb(255, 72, 76, 86)))
        using (SolidBrush lapBase = new SolidBrush(Color.FromArgb(255, 48, 52, 58)))
        using (SolidBrush skin = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (SolidBrush cup = new SolidBrush(Color.FromArgb(255, 245, 245, 240)))
        using (Pen logo = new Pen(Color.FromArgb(255, 217, 119, 87), 0.35f * u))
        using (Pen handle = new Pen(Color.FromArgb(255, 245, 245, 240), 0.35f * u))
        {
            FillR(woodD, -9f * u, 0.2f * u, 18f * u, 2.2f * u);
            FillR(wood, -10f * u, -1.1f * u, 20f * u, 1.3f * u);
            FillR(lapBack, -4.6f * u, -5.4f * u, 9.2f * u, 4.3f * u);
            FillR(lapBase, -5.4f * u, -1.3f * u, 10.8f * u, 0.4f * u);
            for (int i = 0; i < 3; i++)
            {
                float a = i * 1.0472f;
                g.DrawLine(logo, -(float)Math.Cos(a) * 0.6f * u, -3.3f * u - (float)Math.Sin(a) * 0.6f * u, (float)Math.Cos(a) * 0.6f * u, -3.3f * u + (float)Math.Sin(a) * 0.6f * u);
            }
            FillR(cup, 7f * u, -2.9f * u, 1.8f * u, 1.8f * u);
            g.DrawEllipse(handle, 8.5f * u, -2.5f * u, 0.9f * u, 0.9f * u);
            float offA = (float)Math.Sin(T * spd) * 0.7f * u, offB = (float)Math.Sin(T * spd + 3.14) * 0.7f * u;
            FillR(skin, -7.4f * u, -2.6f * u + offA, 2f * u, 2f * u);
            FillR(skin, 5.4f * u, -2.6f * u + offB, 2f * u, 2f * u);
        }
        g.Restore(st);
    }

    void DrawFx()
    {
        for (int i = 0; i < rings.Count; i++)
        {
            Ring r = rings[i]; float f = r.t / 0.35f; float rad = (20f + f * 90f) * Ws;
            using (Pen p = new Pen(Color.FromArgb(A((1f - f) * 0.9f), 255, 240, 180), 3f * Ws)) g.DrawEllipse(p, r.x - rad, r.y - rad, rad * 2f, rad * 2f);
        }
        for (int i = 0; i < sparks.Count; i++)
        {
            Spark s = sparks[i]; float a = s.life / s.max;
            using (SolidBrush b = new SolidBrush(Color.FromArgb(A(a), s.c)))
            { float r = s.size * (0.4f + a); g.FillEllipse(b, s.x - r, s.y - r, r * 2f, r * 2f); }
        }
        for (int i = 0; i < texts.Count; i++)
        {
            FText t = texts[i]; int al = A(1f - t.t);
            SizeF sz = g.MeasureString(t.s, (t.sm ? codeFont : textFont));
            using (SolidBrush sb = new SolidBrush(Color.FromArgb(al, 20, 12, 8)))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(al, t.c)))
            {
                g.DrawString(t.s, (t.sm ? codeFont : textFont), sb, t.x - sz.Width / 2f + 2f, t.y + 2f);
                g.DrawString(t.s, (t.sm ? codeFont : textFont), b, t.x - sz.Width / 2f, t.y);
            }
        }
    }

    void DrawBubble()
    {
        if (bubT <= 0f || bub.Length == 0) return;
        SizeF sz = g.MeasureString(bub, bubFont);
        float bw = sz.Width + 16f, bh = sz.Height + 6f;
        float bx = Clamp(petX - bw / 2f, 4f, W - bw - 4f);
        float by = Math.Max(4f, petY - 10.5f * U - bh - 12f);
        float rad = bh / 2f;
        using (GraphicsPath gp = new GraphicsPath())
        {
            gp.AddArc(bx, by, rad * 2, rad * 2, 180, 90);
            gp.AddArc(bx + bw - rad * 2, by, rad * 2, rad * 2, 270, 90);
            gp.AddArc(bx + bw - rad * 2, by + bh - rad * 2, rad * 2, rad * 2, 0, 90);
            gp.AddArc(bx, by + bh - rad * 2, rad * 2, rad * 2, 90, 90);
            gp.CloseFigure();
            using (SolidBrush b = new SolidBrush(Color.FromArgb(240, 255, 255, 255)))
            using (Pen p = new Pen(Color.FromArgb(255, 60, 40, 30), 2f))
            {
                g.FillPath(b, gp); g.DrawPath(p, gp);
                float tx = Clamp(petX, bx + rad, bx + bw - rad);
                PointF[] tri = { new PointF(tx - 6f, by + bh - 1f), new PointF(tx + 6f, by + bh - 1f), new PointF(petX, by + bh + 10f) };
                g.FillPolygon(b, tri);
            }
        }
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(255, 40, 28, 22)))
            g.DrawString(bub, bubFont, tb, bx + 8f, by + 3f);
    }
}
'@
$iconB64 = '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'
function Fail($e) {
  $log = Join-Path $env:TEMP 'C_Slave_PL_error.txt'
  try { ($e | Out-String) | Set-Content -Path $log } catch { }
  try {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show("C_Slave nie uruchomil sie.`n`n" + ($e | Out-String).Substring(0, [Math]::Min(600, ($e | Out-String).Length)) + "`nPelny log: " + $log, 'C_Slave')
  } catch { }
  exit 1
}
try { Add-Type -TypeDefinition $src -ReferencedAssemblies System.Windows.Forms,System.Drawing,System.Speech -ErrorAction Stop } catch { Fail $_ }
# ikona + skrot na pulpicie (raz przy pierwszym uruchomieniu; reczne odtworzenie: C_Slave.cmd ikona)
try {
  $d = Join-Path $env:LOCALAPPDATA 'C_Slave_PL'
  foreach ($old in @('Pejcz.lnk','CLAUDE_SLAVE.lnk','C_Slave.lnk')) { $ol = Join-Path ([Environment]::GetFolderPath('Desktop')) $old; if (Test-Path $ol) { Remove-Item $ol -Force } }
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  $ico = Join-Path $d 'C_Slave_PL.ico'
  $mark = Join-Path $d 'ikona.ok'
  if (($env:A -eq 'ikona') -or (-not (Test-Path $mark))) {
    [Pejcz]::MakeIcon($ico, $iconB64)
    if ($env:P) {
      $ws = New-Object -ComObject WScript.Shell
      $sc = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'C_Slave PL.lnk'))
      $sc.TargetPath = $env:P
      $sc.WorkingDirectory = Split-Path $env:P
      $sc.IconLocation = $ico
      $sc.WindowStyle = 7
      $sc.Description = 'C_Slave PL'
      $sc.Save()
    }
    Set-Content -Path $mark -Value 'ok'
  }
} catch { }
if ($env:A -ne 'ikona') { try { [Pejcz]::Run($env:A) } catch { Fail $_ } }
