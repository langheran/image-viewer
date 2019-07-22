using System;
using Tesseract;
using RGiesecke.DllExport;
using System.Runtime.InteropServices;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;

namespace ocr
{
    public class Class1
    {
        public Class1()
        {

        }
        [DllExport("GetText", CallingConvention = CallingConvention.Cdecl)]
        public string GetText(string imageFile, string lang="eng")
        {
            var imgsource = new Bitmap(imageFile);
            var ocrtext = string.Empty;
            string assemblyPath = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
            using (var engine = new TesseractEngine(assemblyPath + @"/tessdata", lang, EngineMode.Default))
            {
                using (var img = PixConverter.ToPix(imgsource))
                {
                    using (var page = engine.Process(img))
                    {
                        ocrtext = page.GetText();
                    }
                }
            }
            return ocrtext;
        }
    }
}
