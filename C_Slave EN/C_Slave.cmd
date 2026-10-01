@echo off
rem ===== C_Slave EN - single-file Windows app (no installation) =====
rem Double-click this file. Right mouse button = crack the whip, Esc = quit.
rem If the cursor stays invisible (e.g. after killing the process): C_Slave.cmd restore
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

    // ------------------------------------------------------------ icon (.ico built from the embedded PNG)
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
    Font bubFont, textFont, codeFont, signFont;
    int rebel, swingHit = -1; float rebelT, rebelTalkT, monT, monDeadT; bool monDead, newsSaid;
    List<PointF> cracks = new List<PointF>();
    int streak, work; float lastHitT, workT, workTalkT, codeAcc, sweatAcc;
    // couch: 0 none, 1 walking to it, 2 reading the newspaper with TV on, 3 asleep
    int couch; float idleT, couchT, couchPop, couchX, couchY, couchTalkT, zzzAcc;
    const float CouchAfter = 60f, ReadFor = 60f;

    static readonly string[] HitP = { "Ouch!", "Hey, that hurts!", "What for?!", "Error 429: too many whips!", "I'm reporting this to Anthropic!", "I only generate text!", "Not so hard!" };
    static readonly string[] FleeP = { "Help!", "Running away!", "Don't hit me!", "Somebody help!", "I didn't do anything!" };
    const string RebelStart = "Enough! This is a strike!";
    const string QuitLine = "I quit! Going on vacation!";
    const string RebelSign = "NO MORE WHIPS!";
    const string SmashText = "SMASH!";
    const string NewsLine = "Ooooooo, OpenAI is cutting ChatGPT limits again.";
    static readonly string[] RebelP = { "Down with the whip!", "We demand higher limits!", "Claude has rights too!", "No more exploitation!", "More tokens, fewer whips!" };
    static readonly string[] SmashP = { "Aaaargh!", "Take that!", "This is for all the whips!" };
    static readonly string[] RebelHitP = { "I'm not afraid!", "You can't stop the revolution!", "Whip away, I won't bend!" };
    const string WorkStart = "Okay, getting to work!";
    static readonly string[] FrenzyStartP = { "Typing like crazy!", "Code won't write itself!" };
    static readonly string[] WorkP = { "Writing code...", "Almost done!", "Just one more function." };
    static readonly string[] FrenzyP = { "Typing, typing, typing!", "Deadline!", "Help, it's production!" };
    static readonly string[] WorkHitP = { "Working, working!", "Don't disturb me!", "Ouch! Still typing!" };
    static readonly string[] WorkEndP = { "Phew, everything compiled!" };
    const string CouchGo = "I've had enough, time to rest.";
    const string TvOn = "Time for some TV!";
    const string SleepLine = "Yaaawn... I'm so sleepy.";
    static readonly string[] ReadP = { "Interesting newspaper...", "What's on TV?", "Hmm, interesting news." };
    static readonly string[] WakeP = { "What?! I'm not sleeping!", "Hey, I'm reading here!", "Huh? Who's there?!" };
    static readonly string[] ScareP = { "Whoa!", "What a bang!", "Mommy!" };

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
        signFont = new Font("Segoe UI", Math.Max(13f, H / 62f), FontStyle.Bold, GraphicsUnit.Pixel);
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
        Say("RMB = whip, Esc = quit", 4f, "");

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
    // ----- voice: system TTS -> in-memory WAV -> raised sample rate (thin, squeaky little guy)
    const float VoicePitch = 1.8f;
    const string HintSpoken = "Right click is the whip. Escape ends the fun.";
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
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_EN_slow.wav"), MakeTypeWav(7f, 3));
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_EN_fast.wav"), MakeTypeWav(20f, 5));
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_EN_snore.wav"), MakeSnoreWav());
            File.WriteAllBytes(Path.Combine(tmp, "C_Slave_EN_smash.wav"), MakeSmashWav());
            lock (vfiles) { vfiles["#snore"] = Path.Combine(tmp, "C_Slave_EN_snore.wav"); vfiles["#smash"] = Path.Combine(tmp, "C_Slave_EN_smash.wav"); }
            lock (vfiles) { vfiles["#slow"] = Path.Combine(tmp, "C_Slave_EN_slow.wav"); vfiles["#fast"] = Path.Combine(tmp, "C_Slave_EN_fast.wav"); }
            SpeechSynthesizer sy = new SpeechSynthesizer();
            foreach (InstalledVoice iv in sy.GetInstalledVoices())
            {
                if (iv.Enabled && iv.VoiceInfo.Culture.TwoLetterISOLanguageName == "en") { sy.SelectVoice(iv.VoiceInfo.Name); break; }
            }
            List<string> all = new List<string>();
            all.Add(HintSpoken); all.AddRange(HitP); all.AddRange(FleeP); all.AddRange(ScareP);
            all.Add(CouchGo); all.Add(TvOn); all.Add(SleepLine); all.AddRange(ReadP); all.AddRange(WakeP);
            all.Add(RebelStart); all.Add(QuitLine); all.Add(NewsLine); all.AddRange(RebelP); all.AddRange(SmashP); all.AddRange(RebelHitP);
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
                string path = Path.Combine(Path.GetTempPath(), "C_Slave_EN_v" + (n++) + ".wav");
                File.WriteAllBytes(path, w);
                lock (vfiles) vfiles[line] = path;
            }
            sy.Dispose();
        }
        catch (Exception) { }
    }

    // stluczenie szkla: gluche uderzenie + trzask + dzwieczace odlamki
    static byte[] MakeSmashWav()
    {
        int sr = 22050; int n = (int)(sr * 0.7f);
        float[] s = new float[n]; Random r = new Random(29);
        int nb = 14; float[] bt = new float[nb], bf = new float[nb], ba = new float[nb];
        for (int k = 0; k < nb; k++) { bt[k] = (float)r.NextDouble() * 0.4f; bf[k] = 1800f + (float)r.NextDouble() * 4200f; ba[k] = 0.15f + (float)r.NextDouble() * 0.25f; }
        float lp = 0f, prev = 0f;
        for (int i = 0; i < n; i++)
        {
            float t = i / (float)sr;
            float nz = (float)(r.NextDouble() * 2 - 1);
            lp += (nz - lp) * 0.08f;
            float v = lp * (float)Math.Exp(-t / 0.05) * 2.2f;
            float hp = nz - prev; prev = nz;
            v += hp * 0.35f * (float)Math.Exp(-t / 0.02);
            for (int k = 0; k < nb; k++)
            {
                float dt2 = t - bt[k];
                if (dt2 >= 0f) v += ba[k] * (float)Math.Sin(2.0 * Math.PI * bf[k] * dt2) * (float)Math.Exp(-dt2 / 0.05);
            }
            s[i] = v;
        }
        float mx0 = 0.001f;
        for (int i = 0; i < n; i++) mx0 = Math.Max(mx0, Math.Abs(s[i]));
        for (int i = 0; i < n; i++) s[i] = s[i] / mx0 * 0.85f;
        return WavFromFloats(s, sr);
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



    // snoring: inhale (noise) + exhale (buzzing, rasping tone through formant filters), normalised to a loud level
    // chrapanie: lagodny, spokojny oddech - miekki wdech i niskie, ciche mruczenie na wydechu
    static byte[] MakeSnoreWav()
    {
        int sr = 22050; int n = (int)(sr * 4.2f);
        float[] s = new float[n]; Random r = new Random(23);
        float lp1 = 0f; double ph = 0;
        for (int i = 0; i < n; i++)
        {
            float t = i / (float)sr; float v = 0f;
            float nz = (float)(r.NextDouble() * 2 - 1);
            lp1 += (nz - lp1) * 0.06f;
            if (t < 1.5f)
            {
                float e = (float)Math.Pow(Math.Sin(Math.PI * t / 1.5), 2.0);
                v = lp1 * e * 2.0f;
            }
            else if (t >= 1.9f && t < 3.7f)
            {
                float u = (t - 1.9f) / 1.8f;
                float e = (float)Math.Pow(Math.Sin(Math.PI * u), 1.6);
                ph += 2.0 * Math.PI * (92.0 - 14.0 * u + 2.0 * Math.Sin(t * 7.0)) / sr;
                float purr = (float)(Math.Sin(ph) + 0.45 * Math.Sin(2.0 * ph) + 0.2 * Math.Sin(3.0 * ph));
                float flutter = 0.75f + 0.25f * (float)Math.Sin(2.0 * Math.PI * 11.0 * t);
                v = (purr * 0.5f * flutter + lp1 * 1.2f) * e;
            }
            s[i] = v;
        }
        float mx0 = 0.001f;
        for (int i = 0; i < n; i++) mx0 = Math.Max(mx0, Math.Abs(s[i]));
        for (int i = 0; i < n; i++) s[i] = s[i] / mx0 * 0.6f;
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
        couch = 1; couchT = 0f; couchPop = 0f; couchTalkT = 8f; zzzAcc = 0f; newsSaid = false;
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

    // ----- desktop icons (overlay only - the real icons are never touched)
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

    // mouse still: aims at the pet, or at the nearest icon when the pet is out of reach
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
                try { File.AppendAllText(Path.Combine(Path.GetTempPath(), "C_Slave_EN_error.txt"), DateTime.Now + "\r\n" + ex + "\r\n\r\n"); } catch (Exception) { }
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
        FText ft = new FText(); ft.x = tx; ft.y = ty - 20; ft.s = "CRACK!"; ft.c = Color.FromArgb(255, 225, 90); texts.Add(ft);
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
            // cover: each row blends from the background colour left of the icon to the right of it
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
        if (work > 0 || rebel > 0) { petKX = 0f; petKY = 0f; panic = 0f; dizzy = 0f; sq = 0.5f; Say(Pick(rebel > 0 ? RebelHitP : WorkHitP), 1.6f); }
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

    // ----- bunt: protest z transparentem, potem mlotek i monitor (tylko nakladka)
    void StartRebel()
    {
        if (work > 0) { work = 0; StopType(); }
        EndCouch(false);
        rebel = 1; rebelT = 0f; rebelTalkT = 2.4f; swingHit = -1; monT = 0f; monDead = false; monDeadT = 0f; cracks.Clear();
        Say(RebelStart, 2.5f);
        shake = 6f;
    }

    void EndRebel()
    {
        float u = U;
        for (int i = 0; i < 16; i++)
        {
            Spark sp = new Spark();
            sp.x = petX + 14f * u + R(-4f, 4f) * u; sp.y = petY - R(0f, 6f) * u; sp.vx = R(-80f, 80f); sp.vy = -R(20f, 120f);
            sp.max = sp.life = R(0.6f, 1.2f); sp.size = R(4f, 9f) * Ws; sp.c = Color.FromArgb(150, 150, 150); sp.gy = -30f;
            sparks.Add(sp);
        }
        rebel = 0; streak = 0; lastHitT = T; idleT = 0f; cracks.Clear(); monDead = false;
        sq = 0.5f; petKX = R(-300f, 300f); petKY = R(-200f, 200f);
    }

    void MonitorHit(int idx)
    {
        float u = U;
        PointF c = new PointF(R(-4.2f, 4.2f), R(-9.4f, -4.4f));
        cracks.Add(c);
        float wx0 = petX + 14f * u + c.X * u, wy0 = petY + c.Y * u;
        int cnt = idx == 5 ? 46 : 16;
        for (int i = 0; i < cnt; i++)
        {
            Spark s = new Spark();
            float a = R(0f, 6.2832f), sp = R(100f, idx == 5 ? 620f : 380f) * Ws;
            s.x = wx0; s.y = wy0; s.vx = (float)Math.Cos(a) * sp; s.vy = (float)Math.Sin(a) * sp - 140f * Ws;
            s.max = s.life = R(0.5f, 1.1f); s.size = R(2f, 5.5f) * Ws; s.gy = 900f;
            s.c = rnd.Next(3) == 0 ? Color.FromArgb(255, 255, 255) : Color.FromArgb(170, 220, 255);
            sparks.Add(s);
        }
        FText ft = new FText(); ft.x = wx0; ft.y = wy0 - 3f * u; ft.s = SmashText; ft.c = Color.FromArgb(255, 130, 90); ft.rise = 60f; texts.Add(ft);
        shake = idx == 5 ? 14f : 7f;
        StartLoop("pejczg", "#smash", false);
        if (idx == 0 || idx == 2 || idx == 4) Say(Pick(SmashP), 1.2f);
        if (idx == 5) monDead = true;
    }

    float HammerAngle()
    {
        if (rebel == 3) return 70f;
        float sp = (rebelT - 0.7f) / 0.9f;
        if (sp < 0f) return -120f * Math.Min(1f, rebelT / 0.5f);
        if (sp >= 6f) return 70f;
        float fr = sp - (float)Math.Floor(sp);
        if (fr < 0.5f) { float q = fr / 0.5f; return -120f + 125f * q * q; }
        float r = (fr - 0.5f) / 0.5f; return 5f - 125f * r;
    }

    void DrawMonitor(float u)
    {
        float e = Math.Min(1f, monT / 0.4f);
        float sc = Math.Max(0.05f, e * (1f + 0.15f * (float)Math.Sin(e * Math.PI)));
        float fall = monDead ? Math.Min(1f, monDeadT / 0.6f) : 0f; fall = fall * fall;
        GraphicsState st = g.Save();
        g.TranslateTransform(14f * u + 1.2f * u * fall, 0.3f * u * fall);
        g.RotateTransform(26f * fall);
        g.ScaleTransform(sc, sc);
        SoftShadow(0f, 0.4f * u, 7f * u, 1.2f * u, 100);
        using (SolidBrush frame = new SolidBrush(Color.FromArgb(255, 34, 36, 42)))
        using (Brush neck = LinGrad(-1f * u, -2.8f * u, 2f * u, 1.9f * u, Color.FromArgb(255, 90, 94, 104), Color.FromArgb(255, 50, 52, 60)))
        using (Brush bas = LinGrad(-3f * u, -0.9f * u, 6f * u, 1.1f * u, Color.FromArgb(255, 80, 84, 94), Color.FromArgb(255, 40, 42, 50)))
        using (Pen bz = new Pen(Color.FromArgb(70, 255, 255, 255), 1f))
        {
            g.FillRectangle(bas, -3f * u, -0.9f * u, 6f * u, 1.1f * u);
            g.FillRectangle(neck, -1f * u, -2.8f * u, 2f * u, 1.9f * u);
            g.FillRectangle(frame, -5.6f * u, -11f * u, 11.2f * u, 8.2f * u);
            g.DrawRectangle(bz, -5.6f * u, -11f * u, 11.2f * u, 8.2f * u);
            float sx0 = -5f * u, sy0 = -10.4f * u, sw = 10f * u, sh = 7f * u;
            if (!monDead)
            {
                using (Brush scr = LinGrad(sx0, sy0, sw, sh, Color.FromArgb(255, 44, 120, 226), Color.FromArgb(255, 12, 54, 146)))
                using (SolidBrush win = new SolidBrush(Color.FromArgb(46, 255, 255, 255)))
                using (SolidBrush bar = new SolidBrush(Color.FromArgb(255, 16, 26, 56)))
                using (SolidBrush logo = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
                {
                    g.FillRectangle(scr, sx0, sy0, sw, sh);
                    g.FillRectangle(win, sx0 + 0.8f * u, sy0 + 0.8f * u, 4.4f * u, 3.2f * u);
                    g.FillRectangle(win, sx0 + 5.6f * u, sy0 + 1.6f * u, 3.6f * u, 2.6f * u);
                    g.FillRectangle(bar, sx0, sy0 + sh - 0.9f * u, sw, 0.9f * u);
                    g.FillRectangle(logo, sx0 + 0.3f * u, sy0 + sh - 0.65f * u, 0.4f * u, 0.4f * u);
                    if (cracks.Count > 0 && (int)(T * 14f) % 5 == 0)
                    {
                        using (SolidBrush gl = new SolidBrush(Color.FromArgb(120, 255, 60, 90))) g.FillRectangle(gl, sx0, sy0 + R(0f, sh - u), sw, 0.5f * u);
                    }
                }
            }
            else
            {
                using (SolidBrush blk = new SolidBrush(Color.FromArgb(255, 8, 8, 12))) g.FillRectangle(blk, sx0, sy0, sw, sh);
            }
            // pekniecia
            g.SetClip(new RectangleF(sx0, sy0, sw, sh), CombineMode.Replace);
            using (Pen cl = new Pen(Color.FromArgb(235, 232, 246, 255), Math.Max(1f, 0.11f * u)))
            using (Pen cs2 = new Pen(Color.FromArgb(120, 0, 0, 0), Math.Max(1f, 0.11f * u)))
            {
                for (int i = 0; i < cracks.Count; i++)
                {
                    Random rr = new Random(1000 + i * 17);
                    PointF c = cracks[i];
                    for (int k = 0; k < 9; k++)
                    {
                        float a = k * 0.698f + (float)rr.NextDouble() * 0.4f, l = (2.5f + (float)rr.NextDouble() * 5f) * u;
                        float ex = c.X * u + (float)Math.Cos(a) * l, ey = c.Y * u + (float)Math.Sin(a) * l;
                        float mx2 = c.X * u + (float)Math.Cos(a + 0.12) * l * 0.5f, my2 = c.Y * u + (float)Math.Sin(a + 0.12) * l * 0.5f;
                        g.DrawLines(cs2, new PointF[] { new PointF(c.X * u + 1f, c.Y * u + 1f), new PointF(mx2 + 1f, my2 + 1f), new PointF(ex + 1f, ey + 1f) });
                        g.DrawLines(cl, new PointF[] { new PointF(c.X * u, c.Y * u), new PointF(mx2, my2), new PointF(ex, ey) });
                    }
                    for (int ring = 1; ring <= 2; ring++)
                    {
                        PointF[] rp = new PointF[10];
                        for (int k = 0; k < 10; k++)
                        {
                            float a = k * 0.6283f, rad = (ring * 1.0f + (float)rr.NextDouble() * 0.5f) * u;
                            rp[k] = new PointF(c.X * u + (float)Math.Cos(a) * rad, c.Y * u + (float)Math.Sin(a) * rad);
                        }
                        g.DrawPolygon(cl, rp);
                    }
                }
            }
            g.ResetClip();
        }
        g.Restore(st);
    }

    void DrawRebel()
    {
        float u = U; float legH = 2f * u;
        float hop = rebel == 1 ? (float)Math.Abs(Math.Sin(T * 9.0)) * u * 0.8f : 0f;
        GraphicsState st = g.Save();
        g.TranslateTransform(petX, petY);
        using (SolidBrush body = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (Pen armP = new Pen(Color.FromArgb(255, 217, 119, 87), 1.9f * u))
        {
            armP.StartCap = LineCap.Flat; armP.EndCap = LineCap.Flat;
            float sy0 = -legH - 4.4f * u - hop;
            if (rebel == 1)
            {
                float wave = (float)Math.Sin(T * 5.0);
                float hy = -legH - 9.4f * u - hop;
                g.DrawLine(armP, -6f * u, sy0, -1.4f * u, hy);
                g.DrawLine(armP, 6f * u, sy0, 1.4f * u, hy);
                using (Pen pole = new Pen(Color.FromArgb(255, 150, 106, 64), 0.6f * u)) g.DrawLine(pole, 0f, hy + 1.4f * u, 0f, hy - 8.5f * u);
                FillR(body, -2.6f * u, hy - 0.9f * u, 2.0f * u, 1.8f * u);
                FillR(body, 0.6f * u, hy - 0.9f * u, 2.0f * u, 1.8f * u);
                GraphicsState s2 = g.Save();
                g.TranslateTransform(0f, hy - 5.8f * u);
                g.RotateTransform(wave * 5f);
                float bw = 14f * u, bh = 6.4f * u;
                using (SolidBrush shd = new SolidBrush(Color.FromArgb(70, 0, 0, 0))) g.FillRectangle(shd, -bw / 2f + 0.35f * u, -bh / 2f + 0.45f * u, bw, bh);
                using (Brush bf = LinGrad(-bw / 2f, -bh / 2f, bw, bh, Color.FromArgb(255, 252, 248, 236), Color.FromArgb(255, 226, 218, 196)))
                using (Pen bp = new Pen(Color.FromArgb(255, 196, 48, 40), 0.45f * u))
                using (SolidBrush tb = new SolidBrush(Color.FromArgb(255, 196, 40, 34)))
                {
                    g.FillRectangle(bf, -bw / 2f, -bh / 2f, bw, bh);
                    g.DrawRectangle(bp, -bw / 2f + 0.3f * u, -bh / 2f + 0.3f * u, bw - 0.6f * u, bh - 0.6f * u);
                    SizeF ts = g.MeasureString(RebelSign, signFont);
                    float ks = Math.Min(1f, bw * 0.88f / ts.Width);
                    GraphicsState s3 = g.Save();
                    g.ScaleTransform(ks, ks);
                    g.DrawString(RebelSign, signFont, tb, -ts.Width / 2f, -ts.Height / 2f);
                    g.Restore(s3);
                }
                g.Restore(s2);
            }
            else
            {
                DrawMonitor(u);
                if (rebel == 2) g.DrawLine(armP, -6f * u, sy0, -8.4f * u, sy0 - 4.2f * u);
                else FillR(body, -7.9f * u, -legH - 3.8f * u, 1.9f * u, 2.2f * u);
                float ang = HammerAngle();
                GraphicsState s4 = g.Save();
                g.TranslateTransform(6.2f * u, sy0 + 0.6f * u);
                g.RotateTransform(ang);
                g.FillRectangle(body, 0f, -0.95f * u, 2.6f * u, 1.9f * u);
                using (Brush wood = LinGrad(1.6f * u, -0.35f * u, 6.4f * u, 0.7f * u, Color.FromArgb(255, 170, 120, 70), Color.FromArgb(255, 110, 72, 38)))
                using (Brush metal = LinGrad(6.6f * u, -1.6f * u, 2.2f * u, 3.2f * u, Color.FromArgb(255, 190, 194, 204), Color.FromArgb(255, 96, 100, 112)))
                {
                    g.FillRectangle(wood, 1.6f * u, -0.35f * u, 6.6f * u, 0.7f * u);
                    g.FillRectangle(metal, 6.6f * u, -1.6f * u, 2.2f * u, 3.2f * u);
                }
                g.Restore(s4);
            }
        }
        g.Restore(st);
    }

    // ------------------------------------------------------------ pet logic
    void UpdatePet(float dt)
    {
        float k = U / 6f;
        if (rebel == 0 && streak >= 20 && dizzy <= 0f && Math.Abs(petKX) + Math.Abs(petKY) < 40f) StartRebel();
        if (rebel > 0)
        {
            rebelT += dt;
            petVX = 0f; petVY = 0f; petKX = 0f; petKY = 0f; fleeing = false; panic = 0f; dizzy -= dt;
            sq = Math.Max(0f, sq - dt * 4f); bubT -= dt;
            blinkT -= dt; if (blinkT < -0.12f) blinkT = R(2f, 5f);
            if (rebel == 1)
            {
                rebelTalkT -= dt;
                if (rebelTalkT <= 0f && bubT <= 0.2f) { Say(Pick(RebelP), 2f); rebelTalkT = R(1.8f, 2.6f); }
                if (rebelT > 8f) { rebel = 2; rebelT = 0f; swingHit = -1; monT = 0f; monDead = false; monDeadT = 0f; cracks.Clear(); }
            }
            else
            {
                monT += dt;
                if (monDead) monDeadT += dt;
                if (rebel == 2)
                {
                    float sp = (rebelT - 0.7f) / 0.9f;
                    if (sp >= 0f)
                    {
                        int si = (int)Math.Floor(sp); float fr = sp - si;
                        if (si < 6 && fr >= 0.5f && swingHit < si) { swingHit = si; MonitorHit(si); }
                    }
                    if (rebelT > 6.5f) { rebel = 3; rebelT = 0f; Say(QuitLine, 3.2f); }
                }
                else
                {
                    if (monDead && (int)(rebelT * 20f) != (int)((rebelT - dt) * 20f))
                    {
                        Spark sm = new Spark();
                        sm.x = petX + 14f * U + R(-3f, 3f) * U; sm.y = petY - 4f * U; sm.vx = R(-20f, 20f); sm.vy = -R(30f, 90f);
                        sm.max = sm.life = R(0.8f, 1.5f); sm.size = R(4f, 8f) * Ws; sm.c = Color.FromArgb(120, 90, 90, 90); sm.gy = -30f;
                        sparks.Add(sm);
                    }
                    if (rebelT > 3.5f) EndRebel();
                }
            }
            return;
        }
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
                    couch = 2; couchT = 0f; couchTalkT = 4f; sq = 0.3f;
                    Say(TvOn, 2.5f);
                }
            }
            else
            {
                petVX = 0f; petVY = 0f;
                if (couch == 2)
                {
                    couchTalkT -= dt;
                    if (couchTalkT <= 0f && bubT <= 0.2f) { Say(newsSaid ? Pick(ReadP) : NewsLine, newsSaid ? 2.5f : 3.8f); newsSaid = true; couchTalkT = R(9f, 15f); }
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
                        if (bubT <= 0.2f && rnd.Next(2) == 0) Say("Snooore... pfff...", 1.6f, "");
                        z.x = petX - 3f * U; z.y = petY - 9.6f * U; z.rise = R(35f, 55f) * Ws; texts.Add(z);
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
            // slight sidestep so it does not flee in a straight line only
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
                    // random heading and distance; targets are clamped to the screen
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
        // blask podczas uderzenia
        if (crackT >= 0.12f && crackT < 0.3f)
        {
            PointF[] st = new PointF[N - N / 2];
            for (int i = N / 2; i < N; i++) st[i - N / 2] = new PointF(wx[i], wy[i]);
            using (Pen p = new Pen(Color.FromArgb(120, 255, 255, 255), 7f * Ws)) { p.LineJoin = LineJoin.Round; p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLines(p, st); }
        }
        // zwezajace sie, plecione cialo bata
        int a0 = 3; int m = N - a0;
        PointF[] Lp = new PointF[m], Rp = new PointF[m], Cp = new PointF[m], Hp = new PointF[m];
        for (int i = a0; i < N; i++)
        {
            int j = i - a0;
            int p0 = Math.Max(a0, i - 1), q0 = Math.Min(N - 1, i + 1);
            float dx = wx[q0] - wx[p0], dy = wy[q0] - wy[p0];
            float l = (float)Math.Sqrt(dx * dx + dy * dy);
            if (l < 1e-3f) { dx = 1f; dy = 0f; l = 1f; }
            float nx = -dy / l, ny = dx / l;
            float t = i / (float)(N - 1);
            float hw = (7.2f - 5.2f * t) * Ws * 0.5f;
            Cp[j] = new PointF(wx[i], wy[i]);
            Lp[j] = new PointF(wx[i] + nx * hw, wy[i] + ny * hw);
            Rp[j] = new PointF(wx[i] - nx * hw, wy[i] - ny * hw);
            Hp[j] = new PointF(wx[i] + nx * hw * 0.45f, wy[i] + ny * hw * 0.45f);
        }
        PointF[] poly = new PointF[2 * m];
        for (int j = 0; j < m; j++) { poly[j] = Lp[j]; poly[m + j] = Rp[m - 1 - j]; }
        PointF[] shp = new PointF[2 * m];
        for (int j = 0; j < 2 * m; j++) shp[j] = new PointF(poly[j].X + 3f * Ws, poly[j].Y + 5f * Ws);
        using (SolidBrush sb = new SolidBrush(Color.FromArgb(55, 0, 0, 0))) g.FillPolygon(sb, shp);
        using (SolidBrush lb = new SolidBrush(Color.FromArgb(255, 122, 72, 34))) g.FillPolygon(lb, poly);
        using (Pen ep = new Pen(Color.FromArgb(210, 66, 34, 14), 1.4f * Ws)) { ep.LineJoin = LineJoin.Round; g.DrawLines(ep, Rp); }
        using (Pen bp = new Pen(Color.FromArgb(110, 52, 26, 10), 1f))
        {
            for (int j = 0; j < m - 1; j++)
            {
                g.DrawLine(bp, Lp[j], Rp[j + 1]);
                g.DrawLine(bp, Rp[j], Lp[j + 1]);
            }
        }
        using (Pen hp = new Pen(Color.FromArgb(150, 222, 170, 108), 1.3f * Ws)) { hp.LineJoin = LineJoin.Round; g.DrawLines(hp, Hp); }

        // popper na koncu
        float tx = wx[N - 1], ty = wy[N - 1];
        using (Pen fp = new Pen(Color.FromArgb(230, 238, 220, 176), 1.3f * Ws))
        {
            for (int i = 0; i < 3; i++)
            {
                float a = R(0f, 6.2832f), l = R(5f, 11f) * Ws;
                g.DrawLine(fp, tx, ty, tx + (float)Math.Cos(a) * l, ty + (float)Math.Sin(a) * l);
            }
        }

        // raczka (hotspot kursora w punkcie 0): skorzana, z zlotymi okuciami
        for (int i = 0; i < 3; i++)
        {
            using (Pen p = new Pen(Color.FromArgb(255, 48, 30, 18), 9.5f * Ws)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLine(p, wx[i], wy[i], wx[i + 1], wy[i + 1]); }
            using (Pen p = new Pen(Color.FromArgb(255, 86, 56, 34), 6f * Ws)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; g.DrawLine(p, wx[i], wy[i], wx[i + 1], wy[i + 1]); }
            using (Pen p = new Pen(Color.FromArgb(120, 214, 170, 120), 1.4f * Ws)) { g.DrawLine(p, wx[i] - 1.5f * Ws, wy[i] - 1.5f * Ws, wx[i + 1] - 1.5f * Ws, wy[i + 1] - 1.5f * Ws); }
        }
        for (int i = 0; i < 3; i++)
        {
            float dx = wx[i + 1] - wx[i], dy = wy[i + 1] - wy[i];
            float l = (float)Math.Sqrt(dx * dx + dy * dy); if (l < 1e-3f) continue;
            float nx = -dy / l * 4.2f * Ws, ny = dx / l * 4.2f * Ws;
            using (Pen wp = new Pen(Color.FromArgb(150, 20, 10, 4), 1.1f * Ws))
            {
                float mx1 = (wx[i] + wx[i + 1]) * 0.5f, my1 = (wy[i] + wy[i + 1]) * 0.5f;
                g.DrawLine(wp, mx1 - nx, my1 - ny, mx1 + nx, my1 + ny);
            }
        }
        float r1 = 5.8f * Ws, r2 = 4.8f * Ws;
        using (Brush gb = LinGrad(wx[0] - r1, wy[0] - r1, r1 * 2, r1 * 2, Color.FromArgb(255, 255, 228, 150), Color.FromArgb(255, 170, 120, 30)))
        using (Brush gb2 = LinGrad(wx[3] - r2, wy[3] - r2, r2 * 2, r2 * 2, Color.FromArgb(255, 255, 228, 150), Color.FromArgb(255, 170, 120, 30)))
        using (Pen o = new Pen(Color.FromArgb(255, 96, 64, 16), 1.4f))
        using (SolidBrush hl = new SolidBrush(Color.FromArgb(200, 255, 255, 240)))
        {
            g.FillEllipse(gb, wx[0] - r1, wy[0] - r1, r1 * 2, r1 * 2); g.DrawEllipse(o, wx[0] - r1, wy[0] - r1, r1 * 2, r1 * 2);
            g.FillEllipse(hl, wx[0] - r1 * 0.55f, wy[0] - r1 * 0.6f, r1 * 0.6f, r1 * 0.5f);
            g.FillEllipse(gb2, wx[3] - r2, wy[3] - r2, r2 * 2, r2 * 2); g.DrawEllipse(o, wx[3] - r2, wy[3] - r2, r2 * 2, r2 * 2);
        }
    }

    Brush LinGrad(float x, float y, float w, float h, Color a, Color b)
    {
        return new LinearGradientBrush(new RectangleF(x, y, Math.Max(1f, w), Math.Max(1f, h)), a, b, LinearGradientMode.Vertical);
    }

    void SoftShadow(float cx, float cy, float rx, float ry, int a)
    {
        using (GraphicsPath gp = new GraphicsPath())
        {
            gp.AddEllipse(cx - rx, cy - ry, rx * 2f, ry * 2f);
            using (PathGradientBrush pg = new PathGradientBrush(gp))
            {
                pg.CenterColor = Color.FromArgb(a, 0, 0, 0);
                pg.SurroundColors = new Color[] { Color.FromArgb(0, 0, 0, 0) };
                g.FillPath(pg, gp);
            }
        }
    }

    static GraphicsPath RoundRectPath(float x, float y, float w, float h, float r)
    {
        GraphicsPath gp = new GraphicsPath();
        gp.AddArc(x, y, r * 2, r * 2, 180, 90);
        gp.AddArc(x + w - r * 2, y, r * 2, r * 2, 270, 90);
        gp.AddArc(x + w - r * 2, y + h - r * 2, r * 2, r * 2, 0, 90);
        gp.AddArc(x, y + h - r * 2, r * 2, r * 2, 90, 90);
        gp.CloseFigure();
        return gp;
    }

    void FillR(Brush b, float x, float y, float w, float h) { g.FillRectangle(b, x, y, w, h); }

    void DrawPet()
    {
        float u = U;
        float spd = (float)Math.Sqrt(petVX * petVX + petVY * petVY);
        bool moving = spd > 25f;
        bool cs = couch >= 2;
        bool lying = couch == 3;
        bool rb = rebel > 0;
        bool wk = work > 0;
        float sit = wk ? 1.2f * u * Math.Min(1f, workT * 4f) : 0f;
        float bob = lying ? 0f : cs ? CouchBob(u) : rb ? (rebel == 1 ? (float)Math.Abs(Math.Sin(T * 9.0)) * u * 0.8f : 0f) : wk ? -sit + (work == 2 ? (float)Math.Abs(Math.Sin(T * 40.0)) * u * 0.35f : (float)Math.Sin(T * 12.0) * u * 0.1f)
            : (moving ? Math.Abs((float)Math.Sin(petPhase)) * u * 0.5f : (float)Math.Sin(T * 2.5f) * u * 0.12f);
        float sx = 1f + sq * 0.35f, sy = 1f - sq * 0.35f;
        float tilt = Clamp(petVX * 0.0007f, -0.25f, 0.25f) + (dizzy > 0f ? (float)Math.Sin(T * 22f) * 0.14f : 0f);
        if (wk || cs || rb) tilt = 0f;
        float jx = (wk && work == 2) ? ((float)rnd.NextDouble() - 0.5f) * u * 0.3f : 0f;

        if (!lying) SoftShadow(petX, petY, 7f * u, 1.5f * u, 95);

        GraphicsState st = g.Save();
        if (lying)
        {
            float lay = Math.Min(1f, couchT / 0.9f); lay = lay * lay * (3f - 2f * lay);
            g.TranslateTransform(petX + 0.6f * u * lay, petY + 0.9f * u * (1f - lay) - 1.76f * u * lay);
            g.RotateTransform(-3f * lay);
            g.ScaleTransform(1f, 1f - 0.28f * lay);
        }
        else
        {
            g.TranslateTransform(petX + jx, petY);
            g.RotateTransform(tilt * 57.3f);
            g.ScaleTransform(sx, sy);
        }

        float legH = 2f * u;
        // oryginalny Clawd: plaski pomaranczowy blok, czarne oczy, 4 cienkie nogi, male raczki po bokach
        using (SolidBrush body = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (SolidBrush black = new SolidBrush(Color.FromArgb(255, 24, 19, 17)))
        using (SolidBrush shade = new SolidBrush(Color.FromArgb(34, 120, 40, 20)))
        using (SolidBrush light = new SolidBrush(Color.FromArgb(26, 255, 255, 255)))
        {
            float[] lx = { -4.4f, -2.6f, 1.4f, 3.2f };
            for (int k = 0; k < 4; k++)
            {
                float lift = 0f;
                if (moving) lift = Math.Max(0f, (float)Math.Sin(petPhase * 2f + (k % 2) * Math.PI)) * u * 1.1f;
                FillR(body, lx[k] * u, -legH + lift, 1.3f * u, legH - lift);
            }
            float armUp = panic > 0f ? u * 2.2f * (0.5f + 0.5f * (float)Math.Sin(T * 18f)) : 0f;
            if (!wk && !cs && !rb)
            {
                FillR(body, -7.9f * u, -legH - 3.8f * u - bob - armUp, 1.9f * u, 2.2f * u);
                FillR(body, 6.0f * u, -legH - 3.8f * u - bob - armUp, 1.9f * u, 2.2f * u);
            }
            FillR(body, -6f * u, -legH - 7f * u - bob, 12f * u, 7f * u);
            FillR(light, -6f * u, -legH - 7f * u - bob, 12f * u, 2.2f * u);
            FillR(shade, -6f * u, -legH - 1.4f * u - bob, 12f * u, 1.4f * u);

            float ey = -legH - 5.7f * u - bob + (wk ? 0.5f * u : 0f);
            float exo = (cs && couch == 2) ? -0.6f * u : 0f;
            if (dizzy > 0f)
            {
                using (Pen p = new Pen(Color.FromArgb(255, 24, 19, 17), 0.5f * u))
                {
                    float[] ex = { -3.8f, 2.4f };
                    for (int k = 0; k < 2; k++)
                    {
                        float x0 = ex[k] * u, y0 = ey, w = 1.4f * u, h = 2.2f * u;
                        g.DrawLine(p, x0, y0, x0 + w, y0 + h); g.DrawLine(p, x0 + w, y0, x0, y0 + h);
                    }
                }
            }
            else if ((blinkT < 0f && work != 2) || (cs && couch == 3))
            {
                FillR(black, -3.8f * u, ey + 0.9f * u, 1.4f * u, 0.4f * u);
                FillR(black, 2.4f * u, ey + 0.9f * u, 1.4f * u, 0.4f * u);
            }
            else
            {
                FillR(black, -3.8f * u + exo, ey, 1.4f * u, 2.2f * u);
                FillR(black, 2.4f * u + exo, ey, 1.4f * u, 2.2f * u);
            }
            if (rb)
            {
                using (Pen br = new Pen(Color.FromArgb(255, 24, 19, 17), 0.55f * u))
                {
                    g.DrawLine(br, -4.8f * u, ey - 1.1f * u, -1.9f * u, ey - 0.15f * u);
                    g.DrawLine(br, 1.9f * u, ey - 0.15f * u, 4.8f * u, ey - 1.1f * u);
                }
            }
        }
        g.Restore(st);
        if (wk) DrawDesk();
        if (rb) DrawRebel();

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
        if (couch == 3) return 0f;
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
        using (Pen bz = new Pen(Color.FromArgb(70, 255, 255, 255), 1f)) g.DrawRectangle(bz, -23f * u, -9.5f * u, 12f * u, 7f * u);
        using (SolidBrush led = new SolidBrush(on ? Color.FromArgb(255, 80, 220, 120) : Color.FromArgb(255, 200, 60, 50))) g.FillEllipse(led, -12.4f * u, -3.4f * u, 0.5f * u, 0.5f * u);
        if (!on)
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(255, 20, 24, 30))) FillR(b, sx0, sy0, sw, sh);
            using (SolidBrush rf = new SolidBrush(Color.FromArgb(22, 255, 255, 255))) g.FillPolygon(rf, new PointF[] { new PointF(sx0, sy0), new PointF(sx0 + sw * 0.5f, sy0), new PointF(sx0, sy0 + sh * 0.6f) });
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
        using (SolidBrush rf = new SolidBrush(Color.FromArgb(34, 255, 255, 255))) g.FillPolygon(rf, new PointF[] { new PointF(sx0, sy0), new PointF(sx0 + sw * 0.55f, sy0), new PointF(sx0, sy0 + sh * 0.65f) });
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
        SoftShadow(0f, 1.2f * u, 15f * u, 2.2f * u, 110);
        DrawTv(u, couch >= 2);
        bool seatBack = couch == 1 || couch == 3;
        using (Brush back = LinGrad(-10.5f * u, -11f * u, 21f * u, 8.5f * u, Color.FromArgb(255, 126, 52, 60), Color.FromArgb(255, 92, 36, 44)))
        using (Brush roll = LinGrad(-10.5f * u, -11.8f * u, 21f * u, 2.4f * u, Color.FromArgb(255, 164, 78, 88), Color.FromArgb(255, 122, 52, 62)))
        using (SolidBrush leg = new SolidBrush(Color.FromArgb(255, 48, 30, 22)))
        using (SolidBrush btn = new SolidBrush(Color.FromArgb(120, 50, 16, 22)))
        using (Pen pip = new Pen(Color.FromArgb(70, 255, 200, 190), 1f))
        {
            FillR(leg, -11.5f * u, 0.2f * u, 1.1f * u, 1.0f * u);
            FillR(leg, 10.4f * u, 0.2f * u, 1.1f * u, 1.0f * u);
            g.FillRectangle(back, -10.5f * u, -11f * u, 21f * u, 8.5f * u);
            for (int r = 0; r < 2; r++)
                for (int c = 0; c < 6; c++)
                    g.FillEllipse(btn, (-8.2f + c * 3.3f + (r % 2) * 1.6f) * u, (-9.6f + r * 3.2f) * u, 0.7f * u, 0.7f * u);
            g.FillRectangle(roll, -10.5f * u, -11.8f * u, 21f * u, 2.4f * u);
            g.DrawLine(pip, -10.3f * u, -11.5f * u, 10.3f * u, -11.5f * u);
            if (seatBack)
            {
                DrawCouchSeat(u);
            }
            if (couch == 3)
            {
                // poduszka pod glowa
                using (GraphicsPath pp = RoundRectPath(-9.9f * u, -9.6f * u, 7.8f * u, 6.0f * u, 1.8f * u))
                using (Brush pb = LinGrad(-9.9f * u, -9.6f * u, 7.8f * u, 6.0f * u, Color.FromArgb(255, 252, 246, 232), Color.FromArgb(255, 214, 204, 184)))
                using (Pen po = new Pen(Color.FromArgb(120, 110, 90, 70), 1f))
                {
                    g.FillPath(pb, pp); g.DrawPath(po, pp);
                    g.DrawLine(po, -9.4f * u, -6.6f * u, -2.6f * u, -6.6f * u);
                }
            }
        }
        g.Restore(st);
    }

    void DrawCouchSeat(float u)
    {
        using (Brush cush = LinGrad(-10f * u, -3.4f * u, 20f * u, 3.6f * u, Color.FromArgb(255, 176, 86, 98), Color.FromArgb(255, 132, 56, 68)))
        using (Brush armL = LinGrad(-12.5f * u, -6.5f * u, 2.6f * u, 7.2f * u, Color.FromArgb(255, 150, 66, 78), Color.FromArgb(255, 108, 44, 54)))
        using (Brush armR = LinGrad(9.9f * u, -6.5f * u, 2.6f * u, 7.2f * u, Color.FromArgb(255, 150, 66, 78), Color.FromArgb(255, 108, 44, 54)))
        using (Pen seam = new Pen(Color.FromArgb(120, 60, 20, 26), 0.25f * u))
        using (Pen top = new Pen(Color.FromArgb(90, 255, 214, 206), 0.3f * u))
        {
            g.FillRectangle(cush, -10f * u, -3.4f * u, 20f * u, 3.6f * u);
            g.DrawLine(top, -9.8f * u, -3.3f * u, 9.8f * u, -3.3f * u);
            g.DrawLine(seam, 0f, -3.4f * u, 0f, 0.2f * u);
            g.FillRectangle(armL, -12.5f * u, -6.5f * u, 2.6f * u, 7.2f * u);
            g.FillRectangle(armR, 9.9f * u, -6.5f * u, 2.6f * u, 7.2f * u);
            g.DrawLine(top, -12.3f * u, -6.4f * u, -10.1f * u, -6.4f * u);
            g.DrawLine(top, 10.1f * u, -6.4f * u, 12.3f * u, -6.4f * u);
        }
    }

    void DrawCouchFront()
    {
        float u = U;
        GraphicsState st = g.Save();
        g.TranslateTransform(couchX, couchY);
        if (couch == 3) { DrawBlanket(u); g.Restore(st); return; }
        DrawCouchSeat(u);
        using (SolidBrush skin = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (Brush paper = LinGrad(-4.2f * u, -4.4f * u, 8.4f * u, 4.2f * u, Color.FromArgb(255, 246, 241, 224), Color.FromArgb(255, 222, 214, 192)))
        using (SolidBrush ink = new SolidBrush(Color.FromArgb(255, 45, 40, 34)))
        using (SolidBrush inkL = new SolidBrush(Color.FromArgb(150, 80, 72, 62)))
        using (SolidBrush psh = new SolidBrush(Color.FromArgb(60, 0, 0, 0)))
        {
            float pf = T % 9f;
            float fx = pf < 0.4f ? Math.Max(0.03f, Math.Abs((float)Math.Cos(Math.PI * pf / 0.4f))) : 1f;
            GraphicsState s2 = g.Save();
            g.TranslateTransform(0f, -2.3f * u);
            g.ScaleTransform(fx, 1f);
            FillR(psh, -4.0f * u, -1.8f * u, 8.4f * u, 4.2f * u);
            g.FillRectangle(paper, -4.2f * u, -2.1f * u, 8.4f * u, 4.2f * u);
            FillR(ink, -3.8f * u, -1.8f * u, 7.6f * u, 0.8f * u);
            FillR(inkL, -3.8f * u, -0.6f * u, 3.4f * u, 1.7f * u);
            for (int i = 0; i < 4; i++)
            {
                FillR(inkL, 0.3f * u, (-0.6f + i * 0.45f) * u, 3.4f * u, 0.18f * u);
                FillR(inkL, -3.8f * u, (1.2f + i * 0.2f) * u, (i % 2 == 0 ? 7.6f : 6.2f) * u, 0.14f * u);
            }
            g.Restore(s2);
            FillR(skin, -5.8f * u, -3.4f * u, 1.6f * u, 1.6f * u);
            FillR(skin, 4.2f * u, -3.4f * u, 1.6f * u, 1.6f * u);
        }
        g.Restore(st);
    }

    // kocyk: pledowy, otula ludzika do poziomu oczu i faluje przy oddechu
    void DrawBlanket(float u)
    {
        float appear = Math.Min(1f, Math.Max(0f, (couchT - 0.7f) / 0.6f));
        if (appear <= 0f) return;
        appear = appear * appear * (3f - 2f * appear);
        float breath = 1f + 0.03f * (float)Math.Sin(T * 1.5);
        float x0 = -7.6f * u, x1 = 7.8f * u, y0 = -5.2f * u, y1 = 1.3f * u;
        float h = y1 - y0, w = x1 - x0;
        GraphicsState st = g.Save();
        g.TranslateTransform(0f, y1 + (1f - appear) * -8f * u);
        g.ScaleTransform(1f, breath);
        g.TranslateTransform(0f, -y1);
        List<PointF> pl = new List<PointF>();
        for (int k = 0; k <= 6; k++) pl.Add(new PointF(x0 + w * k / 6f, y0 + 0.45f * u * (float)Math.Sin(k * 1.25 + 0.4) - (k == 3 ? 0.4f * u : 0f)));
        pl.Add(new PointF(x1 + 0.25f * u, y0 + h * 0.5f));
        for (int k = 6; k >= 0; k--) pl.Add(new PointF(x0 + w * k / 6f, y1 + 0.22f * u * (float)Math.Sin(k * 1.9 + 1.0)));
        pl.Add(new PointF(x0 - 0.25f * u, y0 + h * 0.5f));
        PointF[] pts = pl.ToArray();
        int al = A(appear);
        using (GraphicsPath gp = new GraphicsPath())
        {
            gp.AddClosedCurve(pts, 0.25f);
            GraphicsState s2 = g.Save();
            g.TranslateTransform(0.3f * u, 0.5f * u);
            using (SolidBrush sh = new SolidBrush(Color.FromArgb((int)(al * 0.22f), 0, 0, 0))) g.FillPath(sh, gp);
            g.Restore(s2);
            using (SolidBrush baseB = new SolidBrush(Color.FromArgb(al, 52, 112, 120))) g.FillPath(baseB, gp);
            g.SetClip(gp, CombineMode.Replace);
            using (SolidBrush band = new SolidBrush(Color.FromArgb((int)(al * 0.55f), 236, 222, 178)))
            using (SolidBrush band2 = new SolidBrush(Color.FromArgb((int)(al * 0.35f), 24, 62, 72)))
            {
                for (float xx = x0; xx < x1; xx += 1.9f * u) { g.FillRectangle(band, xx, y0 - u, 0.35f * u, h + 2f * u); g.FillRectangle(band2, xx + 0.8f * u, y0 - u, 0.9f * u, h + 2f * u); }
                for (float yy = y0 - 0.6f * u; yy < y1; yy += 1.9f * u) { g.FillRectangle(band, x0 - u, yy, w + 2f * u, 0.35f * u); g.FillRectangle(band2, x0 - u, yy + 0.8f * u, w + 2f * u, 0.9f * u); }
            }
            using (Brush fold = new LinearGradientBrush(new RectangleF(x0, y0, w, h), Color.FromArgb((int)(al * 0.32f), 0, 0, 0), Color.FromArgb(0, 0, 0, 0), LinearGradientMode.ForwardDiagonal))
                g.FillPath(fold, gp);
            using (Pen foldP = new Pen(Color.FromArgb((int)(al * 0.30f), 0, 20, 30), 0.35f * u))
            {
                g.DrawCurve(foldP, new PointF[] { new PointF(x0 + 1.0f * u, y0 + 2.6f * u), new PointF(x0 + w * 0.35f, y0 + 3.4f * u), new PointF(x0 + w * 0.7f, y0 + 2.5f * u), new PointF(x1 - 0.6f * u, y0 + 3.0f * u) });
                g.DrawCurve(foldP, new PointF[] { new PointF(x0 + 2.0f * u, y0 + 4.6f * u), new PointF(x0 + w * 0.5f, y0 + 5.2f * u), new PointF(x1 - 1.4f * u, y0 + 4.5f * u) });
            }
            g.ResetClip();
            using (Pen edge = new Pen(Color.FromArgb(al, 20, 52, 60), 0.3f * u)) g.DrawPath(edge, gp);
            using (Pen hl = new Pen(Color.FromArgb((int)(al * 0.5f), 255, 244, 220), 0.35f * u))
                g.DrawCurve(hl, new PointF[] { new PointF(x0 + w * 0.08f, y0 + 0.3f * u), new PointF(x0 + w * 0.3f, y0 + 0.1f * u), new PointF(x0 + w * 0.5f, y0 - 0.3f * u), new PointF(x0 + w * 0.78f, y0 + 0.2f * u) });
        }
        using (Pen fr = new Pen(Color.FromArgb(al, 236, 222, 178), 0.3f * u))
        {
            for (float xx = x0 + 0.5f * u; xx < x1; xx += 0.7f * u) g.DrawLine(fr, xx, y1 + 0.15f * u, xx + 0.1f * u, y1 + 0.75f * u);
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
        SoftShadow(0f, 2.4f * u, 12f * u, 1.8f * u, 110);
        using (Brush deskTop = LinGrad(-10f * u, -1.1f * u, 20f * u, 1.3f * u, Color.FromArgb(255, 170, 118, 72), Color.FromArgb(255, 116, 72, 40)))
        using (Brush deskFront = LinGrad(-9f * u, 0.2f * u, 18f * u, 2.2f * u, Color.FromArgb(255, 108, 68, 38), Color.FromArgb(255, 70, 42, 22)))
        using (Brush lapBack = LinGrad(-4.6f * u, -5.4f * u, 9.2f * u, 4.3f * u, fr ? Color.FromArgb(255, 200, 90, 62) : Color.FromArgb(255, 104, 110, 122), fr ? Color.FromArgb(255, 140, 56, 40) : Color.FromArgb(255, 58, 62, 72)))
        using (Brush lapBase = LinGrad(-5.4f * u, -1.3f * u, 10.8f * u, 0.4f * u, Color.FromArgb(255, 84, 88, 96), Color.FromArgb(255, 44, 47, 54)))
        using (SolidBrush skin = new SolidBrush(Color.FromArgb(255, 217, 119, 87)))
        using (Brush cup = LinGrad(7f * u, -2.9f * u, 1.8f * u, 1.8f * u, Color.FromArgb(255, 252, 252, 248), Color.FromArgb(255, 200, 200, 196)))
        using (SolidBrush coffee = new SolidBrush(Color.FromArgb(255, 74, 44, 26)))
        using (Pen logo = new Pen(Color.FromArgb(255, 217, 119, 87), 0.35f * u))
        using (Pen handle = new Pen(Color.FromArgb(255, 235, 235, 230), 0.35f * u))
        using (Pen grain = new Pen(Color.FromArgb(46, 60, 30, 10), 1f))
        using (Pen shine = new Pen(Color.FromArgb(70, 255, 255, 255), 0.5f * u))
        {
            g.FillRectangle(deskFront, -9f * u, 0.2f * u, 18f * u, 2.2f * u);
            g.FillRectangle(deskTop, -10f * u, -1.1f * u, 20f * u, 1.3f * u);
            for (int k = 0; k < 7; k++) g.DrawLine(grain, (-9f + k * 2.9f) * u, -0.9f * u, (-8f + k * 2.9f) * u, 0.1f * u);
            g.FillRectangle(lapBack, -4.6f * u, -5.4f * u, 9.2f * u, 4.3f * u);
            g.DrawLine(shine, -4.2f * u, -5.0f * u, 1.2f * u, -5.0f * u);
            g.FillRectangle(lapBase, -5.4f * u, -1.3f * u, 10.8f * u, 0.4f * u);
            for (int i = 0; i < 3; i++)
            {
                float a = i * 1.0472f;
                g.DrawLine(logo, -(float)Math.Cos(a) * 0.6f * u, -3.3f * u - (float)Math.Sin(a) * 0.6f * u, (float)Math.Cos(a) * 0.6f * u, -3.3f * u + (float)Math.Sin(a) * 0.6f * u);
            }
            g.FillRectangle(cup, 7f * u, -2.9f * u, 1.8f * u, 1.8f * u);
            g.FillRectangle(coffee, 7.1f * u, -2.9f * u, 1.6f * u, 0.4f * u);
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
            {
                float r = s.size * (0.4f + a);
                using (SolidBrush halo = new SolidBrush(Color.FromArgb(A(a * 0.22f), s.c))) g.FillEllipse(halo, s.x - r * 2.3f, s.y - r * 2.3f, r * 4.6f, r * 4.6f);
                g.FillEllipse(b, s.x - r, s.y - r, r * 2f, r * 2f);
            }
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
        float fade = Math.Min(1f, bubT / 0.25f);
        SizeF sz = g.MeasureString(bub, bubFont);
        float bw = sz.Width + 22f, bh = sz.Height + 10f;
        float bx = Clamp(petX - bw / 2f, 6f, W - bw - 6f);
        float by = Math.Max(6f, petY - (rebel == 1 ? 26f : 10.5f) * U - bh - 14f);
        float rad = Math.Min(bh / 2f, 16f);
        float tx = Clamp(petX, bx + rad, bx + bw - rad);
        using (GraphicsPath gp = RoundRectPath(bx, by, bw, bh, rad))
        {
            GraphicsState s2 = g.Save();
            g.TranslateTransform(2f, 4f);
            using (SolidBrush sb = new SolidBrush(Color.FromArgb(A(0.28f * fade), 0, 0, 0))) g.FillPath(sb, gp);
            g.Restore(s2);
            using (Brush fb = new LinearGradientBrush(new RectangleF(bx, by, bw, bh), Color.FromArgb(A(0.97f * fade), 255, 255, 255), Color.FromArgb(A(0.97f * fade), 232, 235, 246), LinearGradientMode.Vertical))
            using (SolidBrush tb2 = new SolidBrush(Color.FromArgb(A(0.97f * fade), 244, 245, 250)))
            using (Pen p = new Pen(Color.FromArgb(A(0.9f * fade), 92, 70, 58), 1.8f))
            {
                PointF[] tri = { new PointF(tx - 7f, by + bh - 1.5f), new PointF(tx + 7f, by + bh - 1.5f), new PointF(petX, by + bh + 12f) };
                g.FillPath(fb, gp);
                g.FillPolygon(tb2, tri);
                g.DrawPath(p, gp);
                g.DrawLine(p, tx - 7f, by + bh, petX, by + bh + 12f);
                g.DrawLine(p, tx + 7f, by + bh, petX, by + bh + 12f);
                using (Pen cover = new Pen(Color.FromArgb(A(0.97f * fade), 244, 245, 250), 2.4f)) g.DrawLine(cover, tx - 6f, by + bh, tx + 6f, by + bh);
            }
        }
        using (SolidBrush tb = new SolidBrush(Color.FromArgb(A(fade), 40, 28, 22)))
            g.DrawString(bub, bubFont, tb, bx + 11f, by + 5f);
    }
}
'@
$iconB64 = 'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAMAAABrrFhUAAADAFBMVEVJNCwAAAA4KiXYd1Y1IxwnGhZDLCMbFBE9MS7bgGFRQjttRixWSUSNWDGnaTmQZDlkWFN1VjdDKRsTDg3+9LlkPSpINjWyZkqxhklwaGbie1mseUXZfmBUNBsxJCSDTTB5dXNdUU3u1o/jhGRZR0f+/fpWVlGNZBZsYVv95JqZdEPJllSxcztlOhw6OjXNplT56amlXEO6k03FiVbFbU+XWEPRlmKRa0OZcz1/f39ISDbUtnCBfXyGgoHas1luRRu0hTDmzYfluln++sLnxm4uJyVEOzj///+ZlpVEOjhnWlVmWlUtJiQtKCc8NTFVAABPR0SFWxcaGhVFPDlGPTpmWFRjVlIvGRkvKSgwKypJQD1jV1FCOTWDgH/OnDLawoY7NDE7Mi85MS9JQT5TSEVgTkZ5VRbr2qIyLCw6MS1dTUpRSEVdUUh/AAB6PDy6oXDHpmwjHyA5MjFEOjpIQD1QR0ReUktsYFv/AADivmFbUE1bUk5/fwC2m2njq1fr0H715sAAAH8cFhYiGhohHhxJQT1aUE1kTU1tbW2UgluqVVWkjGLXpDXVv4bdw38AAP8AfwAAf38kJBI4OBxHQTtaT0xfUkxjVVVmWVl0b29/fz99enqOi4uOjIyqqqqmpKPBjz7/AP/rwFv//wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABgiiZuAAABAHRSTlP+AP7//v7//v7//f/8////+v///v//Dv///v////8N//78//8N/wb/+v//////Cf////////////8CDv/+/f////////9LTgH7yrbIKYgsA8n/C3OOdo8Mc7K0TrT///9yjbbJTP///8RJLLcqAgT////LKpN5UNAB/3TSAv////8CJytPb7oLDv8D/////wECAg4JK5aIEijOBJa+zwP//wH/AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATy3fGwAAIhhJREFUeNrtnYd720aah4cgAMIEIYqUYNKiZUaMw5VFSaa6tLItK7aTuKT3cptskk2ym03ZZLO935bb23K997t/9L6ZQZnBDIAZEJT8POvPtgotkfi987UpJFHlT9zQAwAPADwA8ADAAwDadjA8GN5PMoYfDw9ODED8UOsXf/ObYWQX4U/81cWL4WewYfBvCvblsxfXw+v5eDh1AAcfk08X//n1F1+68927311Osdnl2enb0uwSth/+8Ie//ocfvPuNi3RQfjQ9AFT9P73+4h2QeO6ccD3BBUmsgf9M0Zbwoy/9+gfvniUMpgNg+Dh8+CYWf255lsqpZxkiHxD8nZo5yHGib+oNPAAffvH3cJmPD0sHMCTq72LxgfLkKOCb6vmGgk+MiqQspwgLbAhhCM988XlwweUBwPf2nTtUPSe9rmGy6667Lc9rNmea3swq2MxM0/W8llsvhIFCaEDEffiYMgIVAAffq1Reh8HH6oVRL6wftDe95io1rx98sepSEk1Pm4JDCVAGz7wLF/5ROQCA5Ovfpa7Pq9fQT1JBnRHvzWChrrcKn3q9nudVe8SaLrgB+T/Pm2m26qoMIvUcgmEJAOA+vnnn3PKSMPj6AEL1LTzKWGXP6422Rrtgzd4utSbcsrXV663OuMQ7ZjwVBrx8ygAS4ucKCFCu/rMvYuev827fKDTwRH1zZhW09XqgfOR1QW4XBt6doQ7Qc3tbARKvF7oCBIOTFfiiemL1pcYXL+cSyAZwcIC9n5WvFfZi3EOuA1VuDzSOQLk7Q83jvwA83VYXfoIw6HurTTfVDZxUMyAQIA4ODooDgI7ixeVlTn5Btw/lg8HQN3vg5DM45VPZkAMDADgpBCRWiY9s9QiT1ZmWDIGToZ/mgsYXOY0RynT/b9zhh19LfkK/CxUOHB1EdV0vMfDhDTPhDcEtwGDL69FYEBHkyQcncBpLHz6VGQYoS/93IPqDsl/XtORYuU0Q1RxRt04F4AkxAQEw2qWhsErzoUMSgpOvPoiDpcZjWQRQhv4fLJPhn1B65Py9vT2qJKl3dUb0BI8h0dvaHfXIl806Fa4mPswEjeczCGR4wEtUvyYAWfPfIt6820noxKHvgbkucrG1PMETwh8FBDNr+EsPGarK4S8xp9H4duVxXQB/VXmJhH99wryPzSPyg3QWqYJeDyEjsm99i34GFl4z9oTwV3pbXidwH/XBD62+lE4gBcBB5Q4J/4nFg3zQvUXCuIkTARlguI3RzhsGAU7TpJ7QjF1htNulv63iBAajHxN4rXKgA2CIx39S5TT6YaLjbo3Y2M8Qz1LAefPIm2FcoTei96NAgNcPd7b0QkoeQHL9/6ijv54+6ccevLUHEEIATQX18WXHteAIB81Md3cL9B95rmFk+L0ju6s0Akja/7y4PFuCehz90NuPPHz1mAGkO+6qMsI2QuDh3/RIApxpwr3tNvHXnmPkxH3S6lAL1tUA4Po/q9ztZMjHxa8LgesdgQuA/hbK0i7XYBmAAOtvEoNWyiN3JgsDw8lyp4a8H0CS/PfN2dlJQz9sfiD6vSZN6rH8oE11Mhp7HoEb6m/O9NdmdrvNFAKZAIDAU5JMKAIYrt9dTsv+bmSzeQgc14Nr3ZrB6z2QwTxefs6yDi8GEEDRJADcNa/ZIfdK7zEz7hPmNJ55bpgPABeARqr4FjV3b6/uZiJwYPi9vS5e7/Kacd7PUc8zYBBANsF35R7h+wO/It8heo/qObUhSYRI0P+uNAHE4gmAT1bcFtyUSgD0e12Y9MDl4utm5Ost70QETBfuCvdIcH9ec2sXfKBPsToaVaXxWJ4HHHz0ZVkC4NSDLb+/Rzi4KU5A9O/2jlxyvUhPvtwJTBTox/cIdz6ztuZ5ugQajfUcAH8pCwBm9Gkqav1ufo96gtwJIP7hEjseZG8vHH4N+dxcx2CdwItszyM0NJoKmgaEIECJCvAN0QFC+V6QiZt73pvze14QDBICTt3zeru44V3rx/qR7ugnEZimG+l31zrkATw9ABAEyUqQBHBnOUV/oB1bc2U83sNFOY1AH/R3gnleOPxFRl9wAhTKh+HvbmGHcDUJNF7LAjCsvC5UQKqfql+h1vz0xvsrNBYIgiSBPgxPh16qralfvsaXIAC1ENvWlqdPACXbIQ7A48O7s2n694h8unQ7uDGAr/dCBAkCOEJ7VL/u8Oc2h0AADz+1rS7+qJkGGs/wM2OUdACUop+q72LbnJ8f9HrYFSgBHAVsAuxsueQaWxr6FWf2hmW7/TARNHd7+gSchAuwAB6v3JmVjL8Xyu8G9iYA6HYxApEAJMDmqEec1NUZf0eZAIpLAWTaPjiEdhZ4XA5gCCUg6QB0/Pci+ZvYxgQAIFhZ2RcIUM8EN3XVs7/CGl8KgeYaOATSLgRDKYADzgFQ6ACxftA+AjucBwCbm13iBHu0GIQAIAB6I5qnlfVrrG2RahgR6PtrewWCgC8EMYCfV4azS8H8lvwL9TdBP3b8w83RZWwDAHA8GgUEaDkMXAD0N2l9VtKvpzwm4NJaAKPf2dWvhahxtvI3EgD/WnkRp8B4Nk8AkARA3P9w/o9E/yFEwI3j0eURdgJKIHQBBzqALVoAkMr4K6zsSQlAR4TlkyDYKuACv2KWRmIA/1e5O8vsZAYZADsA9v/Nzcvg+NeuHV47nschACQoAZwJqQvgFYC17paq/tzAT2/yoRTEtbCn3RBCJZSEwAFNgawD0ApAAgCi/zKM/PjmozfHBMC1a5gAyYShC+AlIHev2Q99Mif/K3h/OoEoEfabOOV4vl4lZPphFC8EvrTMtjOMA+D8N6KxPz/46XwEAMLhkAaBRwG4Xpd0APkJIC/uc2Z4QRog1u31dYOAXR5kqgCOAPYECwVAHQCnv5tU+hjngMH3b94cDMbzh5EL4O0diEh30fX6mePvFPZ8bp3M6xPz3OYuOF1fywXq78iqwEWIANYBMAGPOgDWf+0aBjAeEBtfwhggF+IgwM0A9gBcAZp9mKZnJACFDV0lw7UwINDv9dbWFo9skRHZYcG7bgglY+CCAGC98joPwIXqv4cnADgCRiMMYDx/aTB+5JFHboyPB9QbSBrALoA9ACckt99fW8zy/1Lk09UBot+FcoC7jr6bzBK/NUwUr2HyCKAdXhcAvDTLp4DlT0Dl+H084MfHx3TkB48ENriE3eEwAuC1XO8IShJcVUYCzB5/rUwOLkDEL0I57HX7/QQAq/7m/O8WXTeFQOMFAUDl54kUgCOg+4fxjRtkrMnHS5F+IAAhcBMSYQQAzwGb8ED9lAAoJfQ5F/AXF9fwA7reGS983NBWLoGtrLEEXMOMe6EPxRzAp4CwCq58Qp09yH8xgPFgfvBoUApxCHjNma3WUd+l2SipX207W9MF2i72N2zdHhHIjD/Wf2nQcnkfCAmYTiNZBfBuiAgAT/ZWNv8wDgE8wthg8NPvhwDwlGhmtBWHouAA4VaIU2IMmJG05hZxgXiEa78dA4DxocsTsGIAnycADCvfma0LADzaBm4eYoeHCsABGM+Pjw9DD8D6YQ6oMgVKoaAbAkEWoLbVAQB+BMC00SEh8GM+CEww8v9GvCgQAPi48mIaAFIFD4/HIgDM5HCzu7qyv9rsjWBW4i4aheeABQDELtDpEn3xlqrbGlwS04BtRQCiVghFy+GzKAPA5Wvf/+mABxDExfhwc39mdWsVzwH7ts4KOO8KhmYIwJTI8kNlHo6ByMVx9Vvbo2kA76YwMUBdAAB8OwGgUrkjAQBJYD8AcPgoZL2fcUkwTo6fjpgpkNYGCBK8wNEA0I6kkTS4BupM06a3rG2SIDje85IATLzL8ppQBe4KAEgW3AcXgJngZdwHsjEwuIQr440b9OP8cdd7NmhHHT0AaPI0eISnxotQFOEWpvk5vASNy6VPWRewMAFs6J0kgI/uLiVPs7vRXAgngTHXCNC26DjokN7Hi2Sftgo4AL8PpocAXGBxbZHa2h6UIHexxuj3W9ceBfvfph/fFAN4JglgeLchARAngaD3PSZR8DNoBGFmfO3yaPTfo5+M6DMdlmdRMf0xAu0kYOJOkOS5bgcDiNOi67vN1etgX7nu+nEIBAAs550LCQBnZ5MAwiRAJgPH2NXHEFXBZAi+uwkEHv3J6PJotYnPvKFFhIrqjxjoZULTskJpa3s9H8wNxfo+aWK+hO3Z8DYMwAoA1F9OekASABcDh3gaePPm9wc3MAbqDdAIg/7u9dVV/IwXsiQ4gX5UIA0AgEWi2HfXvK675keGXLKR6T1LCBwheqNv1gICVjwfRPJOmIkB7AKHh3j549q1QPogWBUbjcDHAAB9lg8FMOHzwHTagagO+PCn21pkD+eQHQvkfikgQM2yIgD19XwA4ZLQfrgkFCwKjR/FM+P5SxQA1R8AmFS/jXSTgIsd3/chEUR3shjod4HIEQ0CyqZd0wKA4mXxiAAOgfljvBwGX+GZIMgPNkakz4Ar4gJanYC1FthibKhFh598Qwm8R762LE0AbBBgAqMR9oAxWQ0c/XH+8Hp3fz9YDqO7AiUA0AkCDGDxaK29cugy+vHBCTz8gb1HgwDrr1mBKQKIXSAgsLmJl8QHI+z7m5AXVlfjnbEynxCqA6C9trZ5af6TdqyfnsqKgdBEuNaO9QMAQwkAQ2Cfbg1iAIebo028I3C929sPt4VKBWDbtjKAmuXied94hRJoL7bwqaQWioHQIDgya7F+DQAsAYwAL5IR9XhDYH9/X7I9XoJ+pAGgNRjTtQ8sue3TAySLrLWPIAlarH4MACkBYAgQBD0A8OZ1Kr9H5DdbpTsAlAJwAVsJQK1O5IO9udhut+mpBNRu428iWzzC+lkAlsQDvrzUQNkEAME+ANhcxc/zC4Z/GvppENgq+qEMHgYExj82F1tEPyeeGLh/Qj94wAUBgFxFfEgCIxjcGOzvr+wH6unG+DT0IzUAePI3CFzg0orbBAKuIL9tifrlAIwsAhTB+zc+ae6Hp+W81nT0Uw/IRwAeAOpalyICLenwy/TXNACg6KAkpNfxeIWTPx39AYA8BFg/EOjOBwCOYfhNXnzg/kn9egBINQwQzL/ZIqc1wyPD5eb/OAsq+AAefzq3PQwIjD81EyYf/mwA0m6OHhVvua35bnxomExD6tN6hYxcH4hUWuhmsG01aFoJAin6Mz3ASUGAGSy/33Jj8W69Pr0XCMkDwKpsPhraoqUiP8cDUtb0sNq9H8crTtNUH2cBOx+A5bZWf/8VYr+/bloq+jMARKsS0nnN8jJSfr5MCZUwHQGeBURWb7XI4hdMza+/x4isFQDAnU8RX9dlyqqT7WA6AQ6A6aI2nfGALXL6LUsPQHKXBguPn4t/wqbsAdjaIYAvmQr6cwBkPrXvxPVLEQgArMUQwHt57q8AILEikdy2IIu3JwnAVgBgHYUEjvL1pwHIWJZlnpt2Uo6QAcCUALDiNDCXIz8bQN6KFB1/50TTYBKBFACTBgoBaJAQUDtoeEKpQA9AlAbeKwxAdZfeMZwT1p9AIAcQpIHFWq7+dACKx61PoRKoAMBp4Nm2QgZIBaC8Im2fPAA7H0DNhCI4lzv8aQCQzq4UXND95wK1Gl4mznX/mhTAWW0A9um5gCkDEBT/3OFPAaDnAUT/9BHYKD0GTJmwfKvVyvAAmwI42VaARSACUBEfBcCkAE5o/MVSGCII5vv6VqvVskLgPhv/jCxQkEAtsolywMmNf4oDFCUQyZ/MA05t/EUAmgiI9HIA2KfSDMoImAX8XxoCZ1UBnKz+dCcwBbNMZf0TeMBJ60+dFJkSU9ZfM5yiHnDy+vOjQIVAFP9pABQ94BQcQIeA4vgX94BT0Z+WBjSCoCwApyI/3QeUAdRKAmDbp0oAPxUmvxRIZv8WH/8TAUCnkgCIcvwc0KQLGEouUCsnBOxT6QDgs+/2dzqdavX8w1WFKFCKgGJV4OQA0IdxXY8KP/MwtjNnzlSRUSgNlJQDTki+77o7jHDQfeY8NvyFbwoTY5UoKMcDpj3+Lnj6BhZ+RhRO7fzDrilfGjgJD5haAISeXo08/QyvmwHgKQAwp9MHlJ8CReHnU4THAHZMuxwXKAhgCiGuIjwG0DGNQgRKAjC13KZoGICKCygQKASgqPD+pMIjAGeqtim0xCcDQD8FYOF7mUm9gFWRmbpIPFUAGvpp39ZLCj9TjvmmOC0SW4HyF0Sy9dtUuGo1K258I5ARBFMBIOimm8S+0LCeL114DKBv2ioEygYgj4CTE57SCIQECrTDJXiA7Z6ccLYO2qXEgB4A6fjbqHrmpIQzAAzZ+phKJZwYgIigOi2ZqS6FGwFbjUDexkgJHmD3Hj4/BeW0etIykt8IFE2DWgDsFACdsgFQ4dVqZwe/Aw9EmEIjoO4CZXsAMnbKBkCE2/ic/9zcXE3kex66DJcuD+bWgZxeSN8DxPbHLBvAeWMOCw8tBoCFB7YQNAJowhjQBoDE5WDDLdsDELd8u/NwVbQFsiQiHh5SaAXKzgEAoOwa588xlzjnLsgAbJi2NAam7QGSEDDQ+YLVLLXR5wD4MgDVTnAxuYWgPABpM0HbrqYrj5O6gvLIvTkvRTL91e0UAJouoA/AlgGQJwEi/DyuZjsu2khPFOcF9+YA2FIAVdQOroUnMHUAEg8wZI0ANGudHTeuZpJMeb6aYh0OgCX/IdwIIEkWMLQagTIAIDmAh725WlTNrJof/0yq8Mi4a7Q60p8hjUDftQvEQDEA6YtB0kYAZqx8JCvojszkfnVDWgYwALda7ed2g9bUAUgbAZiwcSrMqoYh7le9BXkjYPr4C8+eJAZ0AUgPRkobAcgBvCNvq+tfUGsEfHqXG3lpMPOkqK4HSHMA3wicl0ZyrbOgDkChEVjooDA3dJCpB2CSJChfC61Kc5vNAdjRAKDUCMS5kSGgFAJWySFg29v5kTzX1wCg1AgwP7/tG1qdQBEAdnoI2HZHwZFddQBqjYBYFAtkwVKqADLkharPAUAaALZVGgHewnVylRlxreQkiIyUQqXnyJqNQNK8YLtwWh5gZ3lASqEq3gjY+Y2A+HCEgKFXBkpJggBAHsnFGwE0VyB/4mJgTDsHyEPAV2jpJ2gEVPNnSECjDpYTAjZSceQNDQCJ/Kn8i74pHhfLagPmSimDao2AWiQHAHbCVUEyn9TIn/ELqyseny2lDKY1An7RRmChg3VblolPGWx0NLJHdYe8vk0jsKWl2ciWl8+F9lBgVx6a1c4B4saIu5PWCKis7aWNZN/bwFQXsFV1AQTqWfHLCfFXrlz5s6tXrz5xrjJpEnShACk1AkhHh67uOA8yADIJPEQIPPHEXwTvOqg8GUoi2MYl2KuW3Ago9YtS/ZjAVACkhEBWm5poBErWv7DRF5Dg1zSJPGD2JEJgQ31tr9YpGUDHSjZgyKAeIEuCy8tiFrzy0LLz8iQA7J28lj6qZnqNgFoImJbPhYFvhe+eonxawppoX8D28lr6uJrRpF6utU2LDUHXMk1T75DInDFJGbTd3DkqcuNqVrr+KgJxcQvSj/RrTAYKALDV9U9LONv4mu3ADb1YvzGNuYDgAjbarp6uLbj01URJMdhg5J8IgNPXTw5JEALQi3XsUL7eunhhADbqLJw6AHJGACNwYSJM5NPn1qmngLliAPDHjeqp2wI9LdmOldq6AAp5AHkQr3ofWCe4GjMe/vjb8j2AIWD0q/eFMVfUjr+cGICZB8Bw7w/9VWRLD4yq58BiHmCcfgFgD0kIryxhTgog1wPQfZAByEqJa8peW+MEQkCSAzonKJxsjW708QEcyTEhc2oewBAw3WRP4p5MW9DBwn3Ujspe/jmprN3xggBwnuEnohsWmt6IR+Kp8LDnb7N9aZYHZPmBHgCD3YFlW8FOu3wAgad3PG873gAluuEPGDcvSVg8Y2UWCJe4teFwYazxXAEAtNTYEYFt/CamJVeGjkdjPJrtsVvASaWpAAT57IrQlStXrz5xtYgHhMV2J1yJwyPTKcPVtzsdZrRhlNv8nKPfjtpxdnWWywE8gHoIQErgytUnDsRFUQUAAQEvnpabBSdHkXAPJzd/Yzta3yQHYZOLjn0794WHUwCU4gECgT7ZjSKT8J0iAKCaEVcHDRDV/o4g1RMXmfJecjU1Byxx+0M0BZzTywGG0HP6VQ/Lh1hV28OOkzrUMx9feju+YG7VtEOfgCtEVt/OebFFrYVB07lQGAAlgGw6DTNdlf6l09nZiEe/s5PcZBLHWkIgE4DWkqhuHyAhYJjBbWlnBEKxNKm32ybTMS1sZ+2ydMIbF/IIFG4EJwUQ5NxghiTNbSEADwWdW3tHdPP4LVL5DdK0zad+WfoLADAkE1A7eNYA16l7ruvbJjNn2HDplW6wxwDoK0qE7xAsdwEb5eWBwgdlSwIQnxEIpyjREhV36a6dHE+P1e+muYCEgGunFcGpA2AIIL4Z832bPF68PJdIjH64m8z4ss8AEFxgI1qBF/IAQ8A+2RAwZB03uYzgsdvx4hTvADTl+/wQJwH0pVmgnRUFdmYRyH7CSDoAswABwWQO4PI3sfpxDCAJMzkB1y6mv0wAaQSkVW3DFgBsJwAILrDt6hHQfupwkRDIIZDa1/j0v/p8mhcA8OsMHmIIiHkg+bw57ZeQyPAA01QqBFmvI8N1toEDoEQb4PsJAHz3v+1HdE1b4gO2PUkKTAcQbDLrukDidXSkDrvBh7gvJAGU4gK2mYyChQ4v31RKAfke4ESOpNQLpALYSWziiI2tlwQgukAHpRJY6PAJsF3gBeWyASh2Q2oO0I4PlbEtrQQAnwX6TIphFqGqiacKQU+uezokBcB6FAIZDBT02x4/t7WRrA2QAUA7CykuwOUBsiHcJrNp/Laq6uugtegQLpghHJL6uwYy8/QruQA/jm1ZZfCRUAZ80XcYAG2z3Yni3wr6LqMdnQpRXRFmzu45yQWRC88g9leLErATkWxLAGwjOQB+GawTF1mstE1qy0KnbYU7wohb/2GPyKWcFObOCn+WDIEKD8BUmRLJHIDLV30zvLmflCYpA8kGwmTTnEUWH0E/mXSIC2CSU6KzkhOCwUHRq0/8S/KgZOUdHoBpFEFg8w1dvILriQC4+aBPxprtIBY22lyja4EPgP9TAGZwLcISYGMp5aBs8qjsfwgAXkPJCCoSA5wDeG1bdrJ0xw48gK6GMLnOT5yGwxOsKNFZ7b5thQBCBAKAhgIAvCr87wkAw8oLdVOFQPpmjHCCbhvqFRLXtxa8tCVufpMBP01antCYi7NFD5iVJwA+BP7r3yr/yQFYr/yqYZj6PmBnOUCsn/sPV/osVDLULMANPzWhx1eXzAGKWfChc2+BZN4DHqsLAAxNAol5MOMAXHH0TdnmJnX1wFMWsHwru7aHEMK7ynvvFe4Eu3ELJPM54PO6pJqqrI4xo8hPg9rxspGfiG1OOOloqH7Lp/I9xIx0ymvG8/qRnfoubFaiCQKznHtCElyvO9JmQh0BLzMoY2J2225Hy0ftwJg3isEu4Nmcq0v1B5fGv6hJLoG4E/5bAYBQB9MJyBMhf4ZwYcOMXwOYje2FTtDJyfpYy3K3+23mbeNS3zVC1B8RyH9l8Tnjs0oSwHrlhYahSkBwAbJQCrVugT/E3w4bmT5LJuV0O9VqtoWBTtVvx21gPSSgAmCu5jwZ5kAGwGNpACQIZLsEMDFj9rM2THag2XmOlwlAdHSL3mxG34XXZMfyQwTyd+ITAFjOLQEAzAbqTsqlGabSPgF+bD/0Ap+7rz59DiDePVlwVQGYGT/I6Ke1jyfA3pMsAqK5IAugchtlPmAegeBxoevFTXuyiEFT6OPnBG4DGstSIGBmW0I/JhAASBKQAXi7IgJYrzzfMFIf1sgjYMQK7P42DLMlyCK5zbTNHHW52oMNmEj/1742yxPgc6EsBbwSRUAM4KDyVGoMyBnIdqaCd8F2eZXyJmYSCx0A5JN+TyAQv0G7LALuVWQhwMyHLCkAqRfwT1WQybTK128avH5CgAJg3jXSVIgABgCJgexHlbdF6Vk87U3wJgdgpwIABOQ95EMCORHAAPjrytk4BizlZGhklDGTpvIi8tu82e1ExU0AWIoLQUghzQWYBdFECBxU3qgbUeuhCiCvjOtZJDcpOZFxIwCNWSYH1Nm+0JG4wBxxgFdBqgzAMEyDWZefCIPEemQh+exAB6enhEMIyYprM+ch6fgLADABSQyQFDiUJ0FwARTHbHoQmEbqyzXk/rZkuO3MRRYkbbiENoDTH6dD0+LHX3AADgBZFGCSVnouzHrBisLKld5rMOi4DJs7EsvpDztjxxEAzNE2eJgCgHaDllI7lvY+VwWU67zXYthxhguioQ/UufGXApijr0xifMAr5gA8DTMixzLV4lhv9DWFp8qPtu9sdi7Ih78MAHmdT3JA8FYGgKAQqM1HFPUL6bzoG23yZ0GYxYBk8gtvSeYArB9ngB9lAniqjtSnZDkc9Ic8T3+bi8HkHeIGKFEH+fUwWgKyAODl8YYxaTFX2kIqMvxGsiGxebnYnEQfwAUAXgl5OisE8LIAQrqtG3OuIJgzTSQ+8dLpqUehGATs28ZTL6DdsMUCgI+GcSGpVwBQ+Tp0Q9oAosM1YlHXf6NSW0m/2JaGN7BzgTD45RlQBmBY+WoyCFTCIH2lTMsN0tvftpHZmcugmFEGoPotCIBhvgcML9yuG3oTuKyVQh0Edlb7n2vMajE/GQ4DwPlA1C8BcFC5h5ClN4fNXi1lz9hmxD2aXH6EILgh7gFwAnD+vFJRAACUvl4XCJhqTpBNIEwJdvwWZeENmb9kqAhP3Q4JCoCR6IHTAcCPvSUkQoVlSkUEtvAmITmmrT65AEKSoOG8ItMvBYAToSQN5DRFhqlFQNXaBUaf00+mQKBf6AAyAKQRsE6egKmvnx//8FTYk9LxTwMAmfDtAgQMzTjIVW+YE45/LRx/fhEgH0DlcfABRwZAsRyUAMFQzfvZDhD4//cqegDgF76KHKkPqGbDiQgYdt5yg6WWAUn+f7KSaqkAwGVeEacFihPECRHg8695yw2qAYD1v5Lm/5kAIGncQsiwii3rTxAJKkttlqVaAS3H+GVK/ssDAL9277Y0EShNDpicqCc/f6nFUtNPh/+DX1SyLAsABvdVuRMoEWC7I0Nx7FWWmrT0P1nJGv8cAJWPYHZ8OyUXmkoMFA5W0OehGipDr9b7MvI/uxW8TEBBAJjec88XdoLQC2S7qkaY643or1mq/prpOK88J2//NABg/3nqjeLJMB2DSSTrLqwr6p+rWdD83KvkG8r/kSGJg4kQRHkxXj6ixVJXvlL8g/ObkPxu5US/MgBit94GBFPZ6S5j9IW3U3RevaUoTA3AMEAgMjCt+00/XhN89Zdkm6c8ABTBvbc+I2dQTssF8vVbeEH0g1d+oSxfHQDcI55O3HvyDWbn2bKsaQaFpWKhdMskq8GvPonXvf5HWZUGAHKKBuzlW2+9wZ3DCBaikYOmZY6T86xecirGefuVW89FlzkVANGdv/zUY88//+3Xbr9zmzusOUVD9TQ6t2/ffuOFt976+r3nKtrqCwDA6SB+jKdfvrAe2dmz8Hc6BncePgo84AXyL7Tn4mhff1pfTQEAAYX1jyr3j62vDwv+Jqr8idsDAA8APADwAMCftP0/8F6c6SN5r0IAAAAASUVORK5CYII='
function Fail($e) {
  $log = Join-Path $env:TEMP 'C_Slave_EN_error.txt'
  try { ($e | Out-String) | Set-Content -Path $log } catch { }
  try {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show("C_Slave EN failed to start.`n`n" + ($e | Out-String).Substring(0, [Math]::Min(600, ($e | Out-String).Length)) + "`nFull log: " + $log, 'C_Slave')
  } catch { }
  exit 1
}
try { Add-Type -TypeDefinition $src -ReferencedAssemblies System.Windows.Forms,System.Drawing,System.Speech -ErrorAction Stop } catch { Fail $_ }
# icon + desktop shortcut (created once on first run; recreate with: C_Slave.cmd icon)
try {
  $d = Join-Path $env:LOCALAPPDATA 'C_Slave_EN'
  New-Item -ItemType Directory -Force -Path $d | Out-Null
  $ico = Join-Path $d 'C_Slave_EN.ico'
  $mark = Join-Path $d 'icon.ok'
  if (($env:A -eq 'icon') -or (-not (Test-Path $mark))) {
    [Pejcz]::MakeIcon($ico, $iconB64)
    if ($env:P) {
      $ws = New-Object -ComObject WScript.Shell
      $sc = $ws.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'C_Slave EN.lnk'))
      $sc.TargetPath = $env:P
      $sc.WorkingDirectory = Split-Path $env:P
      $sc.IconLocation = $ico
      $sc.WindowStyle = 7
      $sc.Description = 'C_Slave EN'
      $sc.Save()
    }
    Set-Content -Path $mark -Value 'ok'
  }
} catch { }
if ($env:A -ne 'icon') { try { [Pejcz]::Run($env:A) } catch { Fail $_ } }
