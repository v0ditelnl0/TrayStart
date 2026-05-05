/*
cls

set WinDirNet=%WinDir%\Microsoft.NET\Framework
IF EXIST "%WinDirNet%\v3.5\csc.exe" set csc="%WinDirNet%\v3.5\csc.exe"
IF EXIST "%WinDirNet%\v4.0.30319\csc.exe" set csc="%WinDirNet%\v4.0.30319\csc.exe"

set /a RND=1000+9000*%RANDOM%/32768

set exePath="%tmp%\%~n0_%RND%.exe"

%csc% /nologo /target:winexe /out:%exePath% %0

IF NOT EXIST %exePath% pause

start "" /D "%~dp0" %exePath% %1

del /f /q "%tmp%\%~n0_*" > nul 2>&1

tasklist /fi "imagename eq %~n0_%RND%.exe" /fo csv

exit 0
*/

using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

namespace TrayStart
{
    public class TrayStart : Form
    {
        #region Settings

        private string executePath = "ping.exe";
        private string executeArgumetns = "8.8.8.8 -n 10";
        private string letters = "PN";

        #endregion Setting

        private const string version = "v0.7";
        private const string formText = "TrayStart";
        private Size formSize = new Size(600, 300);
        private Font formFont = new Font("Microsoft Sans Serif", 11);

        private TextBox logTextBox = new TextBox();
        private NotifyIcon notifyIcon = new NotifyIcon();
        private ContextMenu contextMenu = new ContextMenu();

        private int flashCounter = 0;
        private Thread flashThread = null;
        private Process mainProcess = new Process();

        [STAThread]
        static void Main()
        {
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new TrayStart());
        }
        public TrayStart()
        {
            KillOtherProcessesAsync();

            EnableSSL();

            logTextBox.Dock = DockStyle.Fill;
            logTextBox.Multiline = true;
            logTextBox.ScrollBars = ScrollBars.Vertical;

            Controls.Add(logTextBox);

            SuspendLayout();

            Opacity = 0;
            AutoScaleDimensions = new SizeF(6F, 13F);
            AutoScaleMode = AutoScaleMode.Font;
            Size = formSize;
            MinimumSize = formSize;
            Font = formFont;
            FormBorderStyle = FormBorderStyle.Sizable;
            StartPosition = FormStartPosition.CenterScreen;
            Text = formText + " - " + executePath;
            MinimizeBox = false;
            ShowInTaskbar = false;

            FormClosing += (sender, args) =>
            {
                FormVisibleChange();
                args.Cancel = true;
            };

            Load += (sender, args) =>
            {
                MenuBuilder();
                NotifyIconBuilder();
                StartProcess(executePath, executeArgumetns);
                ScriptUpdateAsync();
            };

            ResumeLayout(false);
            PerformLayout();
        }
        private void KillOtherProcessesAsync()
        {
            (new Thread(delegate ()
            {
                Process[] processes = Process.GetProcesses();
                string currentName = Path.GetFileNameWithoutExtension(Application.ExecutablePath);
                currentName = currentName.Substring(0, currentName.Length - 4);

                string currentMainProcessName = Path.GetFileNameWithoutExtension(executePath);

                foreach (Process process in processes)
                {
                    try
                    {
                        if (process.ProcessName.Contains(currentMainProcessName)) process.Kill();
                    }
                    catch (Exception) { }
                }

                foreach (Process process in processes)
                {
                    try
                    {
                        if (process.ProcessName.Contains(currentName) && process.Id != Process.GetCurrentProcess().Id) process.Kill();
                    }
                    catch (Exception) { }
                }
            })).Start();
        }
        private void EnableSSL()
        {
            ServicePointManager.Expect100Continue = true;
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls;

            try { ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072; } catch (Exception) { }

            ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, sslPolicyErrors) => true;
        }
        private void ScriptUpdateAsync()
        {
            Log("Start script update...");
            (new Thread(delegate ()
            {
                try
                {
                    HttpWebRequest request = (HttpWebRequest)WebRequest.Create("https://raw.githubusercontent.com/v0ditelnl0/TrayStart/refs/heads/main/TrayStart.bat");
                    HttpWebResponse httpWebResponse = (HttpWebResponse)request.GetResponse();
                    string response = new StreamReader(httpWebResponse.GetResponseStream(), Encoding.UTF8).ReadToEnd().ToString();

                    httpWebResponse.Close();

                    Regex regex = new Regex("private const string version = .+?;", RegexOptions.IgnoreCase);

                    Match match = regex.Match(File.ReadAllText(GetBatPath(), Encoding.UTF8));
                    string oldVersion = match.Success ? match.Value : "";

                    match = regex.Match(response);
                    string newVersion = match.Success ? match.Value : "";

                    if (response.Contains(GetType().Name) && !oldVersion.Equals(newVersion))
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(GetBatPath()));

                        File.WriteAllText(GetBatPath(), GetScriptWithSettings(response), Encoding.UTF8);

                        StartProcess("cmd.exe", "/c \"" + GetBatPath() + "\"");
                    }
                }
                catch (Exception exeption) { Log(exeption.ToString()); }
            })).Start();
        }
        private string GetBatPath()
        {
            string batPath = Path.GetFileNameWithoutExtension(Application.ExecutablePath);
            return Directory.GetCurrentDirectory() + "\\" + batPath.Remove(batPath.Length - 5) + ".bat";
        }
        private string GetScriptWithSettings(string newScriptContent)
        {
            try
            {
                string batText = File.ReadAllText(GetBatPath(), Encoding.UTF8);
                string oldSettings = Regex.Match(batText, "#region Settings[\\s\\S]+?#endregion Setting", RegexOptions.IgnoreCase).Groups[0].Value;
                return new Regex("#region Settings[\\s\\S]+?#endregion Setting").Replace(newScriptContent, oldSettings, 1);
            }
            catch (Exception exeption) { Log(exeption.ToString()); }
            return "";
        }
        private void Log(string text)
        {
            string[] textLines = text.Split('\n');
            string textToLog = logTextBox.Text;
            string date = DateTime.Now.ToString("[dd.MM.yyyy HH:mm:ss] - ");

            foreach (string textLine in textLines)
            {
                string line = textLine.Trim();
                if (!line.Equals("")) textToLog += ((textToLog.Equals("") ? "" : "\r\n") + date + line);
            }

            string[] logLines = textToLog.Split(new string[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries);

            textToLog = "";

            for (int i = (logLines.Length < 100 ? 0 : logLines.Length - 100); i < logLines.Length; i++)
            {
                textToLog += logLines[i] + "\r\n";
            }

            try
            {
                Invoke(new Action(() =>
                {
                    logTextBox.Text = textToLog.Trim();
                    logTextBox.SelectionStart = logTextBox.Text.Length;
                    logTextBox.ScrollToCaret();
                    logTextBox.Refresh();
                }));
            }
            catch (Exception) { }
        }
        private void StartProcess(string exePath, string arguments)
        {
            try
            {
                KillMainProcess();

                mainProcess = new Process();

                Log("\"" + exePath + "\" " + arguments);

                mainProcess.StartInfo.UseShellExecute = false;
                mainProcess.StartInfo.RedirectStandardOutput = true;
                mainProcess.StartInfo.RedirectStandardError = true;
                mainProcess.StartInfo.CreateNoWindow = true;
                mainProcess.EnableRaisingEvents = true;

                mainProcess.StartInfo.FileName = exePath;
                mainProcess.StartInfo.Arguments = arguments;

                mainProcess.Exited += (sender, args) => SetIcon(letters, Brushes.Red, false);

                mainProcess.OutputDataReceived += (sender, args) => ProcessActivity(args.Data);
                mainProcess.ErrorDataReceived += (sender, args) => ProcessActivity(args.Data);

                mainProcess.Start();

                mainProcess.BeginOutputReadLine();
                mainProcess.BeginErrorReadLine();

            }
            catch (Exception exception) { Log(exception.ToString()); }
        }
        private void KillMainProcess()
        {
            try { mainProcess.Kill(); } catch (Exception) { }
            try { mainProcess.CancelOutputRead(); } catch (Exception) { }
            try { mainProcess.CancelErrorRead(); } catch (Exception) { }
            try { mainProcess.Close(); } catch (Exception) { }
            SetIcon(letters, Brushes.Red, false);
        }
        private void ProcessActivity(string output)
        {
            if (output != null)
            {
                if (flashThread != null && flashCounter == 0) flashThread.Abort();

                if (flashCounter == 0)
                {
                    flashCounter = 4;
                    flashThread = new Thread(delegate ()
                    {
                        bool action = true;
                        do
                        {
                            try
                            {
                                Process.GetProcessById(mainProcess.Id);
                                action = !action;
                                SetIcon(letters, Brushes.Black, action);
                                Thread.Sleep(500);
                            }
                            catch (Exception) { }

                            flashCounter--;

                        } while (flashCounter > 0);

                        SetIcon(letters, Brushes.Black, false);
                    });

                    flashThread.Start();
                }
                else
                {
                    flashCounter = 4;
                }

                if (!Debugger.IsAttached) output = Encoding.GetEncoding(866).GetString(Encoding.GetEncoding(1251).GetBytes(output));
                Log(output);
            }
        }
        private void NotifyIconBuilder()
        {
            SetIcon(letters, Brushes.Black, false);
            notifyIcon.Visible = true;
            notifyIcon.Text = Path.GetFileName(executePath);

            notifyIcon.ContextMenu = contextMenu;
            notifyIcon.DoubleClick += (sender, args) =>
            {
                if (((MouseEventArgs)args).Button == MouseButtons.Left) FormVisibleChange();
            };
        }
        private void MenuBuilder()
        {
            MenuItem[] menuItems = new MenuItem[] { new MenuItem(), new MenuItem(), new MenuItem(), new MenuItem() };

            menuItems[0].Text = "Start";
            menuItems[0].Click += (sender, args) => StartProcess(executePath, executeArgumetns);

            menuItems[1].Text = "Stop";
            menuItems[1].Click += (sender, args) => KillMainProcess();

            menuItems[2].Text = "Exit";
            menuItems[2].Click += (sender, args) =>
            {
                KillMainProcess();
                notifyIcon.Visible = false;
                Process.GetCurrentProcess().Kill();
            };

            menuItems[3].Text = "Folder";
            menuItems[3].Click += (sender, args) => Process.Start("explorer.exe", Directory.GetCurrentDirectory());

            contextMenu.MenuItems.AddRange(menuItems);
        }
        private void FormVisibleChange()
        {
            if (Opacity != 0)
            {
                Opacity = 0;
            }
            else
            {
                Opacity = 255;
                Activate();
            }
        }
        private void SetIcon(string text, Brush backgroundBrush, bool action)
        {
            int iconWidth = 32;
            int iconHeight = 32;

            float fontHeight = iconHeight;
            Font iconFont = new Font(Font.FontFamily, fontHeight, FontStyle.Bold);

            Bitmap bmpIcon = new Bitmap(iconWidth, iconHeight);
            Graphics graphics = Graphics.FromImage(bmpIcon);

            do
            {
                fontHeight -= 0.1f;
                iconFont = new Font(Font.FontFamily, fontHeight, FontStyle.Bold);
            } while (graphics.MeasureString(text, iconFont).Width > iconWidth);

            Rectangle iconRectangle = new Rectangle(0, 0, iconWidth, iconHeight);

            graphics.FillRectangle(backgroundBrush, iconRectangle);

            graphics.DrawString(text, iconFont, Brushes.White, iconRectangle, new StringFormat() { LineAlignment = StringAlignment.Center });
            if (action) graphics.FillEllipse(Brushes.Red, new Rectangle(iconWidth / 4 * 3, iconWidth / 4 * 3, iconWidth / 4, iconHeight / 4));

            try { notifyIcon.Icon = Icon.FromHandle(bmpIcon.GetHicon()); } catch (Exception) { }
            try { Invoke(new Action(() => { Icon = Icon.FromHandle(bmpIcon.GetHicon()); })); } catch (Exception) { }
        }
    }
}
