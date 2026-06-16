package woyou.aidlservice.jiuiv5;

import android.graphics.Bitmap;
import woyou.aidlservice.jiuiv5.ICallback;

interface IWoyouService {
    void updatePrinterState(in int type, ICallback callback);
    void sendRAWData(in byte[] data, ICallback callback);
    void setAlignment(in int alignment, ICallback callback);
    void setFontName(in String typeface, ICallback callback);
    void setFontSize(in float fontSize, ICallback callback);
    void printText(in String text, ICallback callback);
    void printTextWithFont(in String text, in String typeface, in float fontSize, ICallback callback);
    void printColumnsText(in String[] colsTextArr, in int[] colsWidthArr, in int[] colsAlign, ICallback callback);
    void printBitmap(in Bitmap bitmap, ICallback callback);
    void printBarCode(in String data, in int symbology, in int height, in int width, in int textPosition, ICallback callback);
    void printQRCode(in String data, in int modulesize, in int errorlevel, ICallback callback);
    void printOriginalText(in String text, ICallback callback);
    void commitPrinterBuffer();
    void enterPrinterBuffer(in boolean clean);
    void exitPrinterBuffer(in boolean commit);
    void lineWrap(in int n, ICallback callback);
    void cutPaper(ICallback callback);
    void getPrinterSerialNo(ICallback callback);
    void getPrinterVersion(ICallback callback);
    void getServiceVersion(ICallback callback);
    void getPrinterModal(ICallback callback);
    void getPrinterPaper(ICallback callback);
    void getFirmwareStatus(ICallback callback);
    void getHeadLethargic(ICallback callback);
    void getPrinterDistance(ICallback callback);
    void setWidth(in int width, ICallback callback);
    void setVoltage(in int voltage, ICallback callback);
    void hasPrinter(ICallback callback);
    void printBitmapCustom(in Bitmap bitmap, in int type, ICallback callback);
}
