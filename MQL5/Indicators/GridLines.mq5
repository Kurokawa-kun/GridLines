//+------------------------------------------------------------------+
//|                                              HorizontalLines.mq5 |
//|                                         Copyright 2024, Kurokawa |
//|                                   https://twitter.com/ImKurokawa |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Kurokawa"
#property link      "https://twitter.com/ImKurokawa"
#property version   "1.00"
#property indicator_chart_window
#property indicator_color1     clrBlack   //  コンパイル時における警告メッセージ抑止のため
#include <CheckEnvironment.mqh>
#include <ChartObjects\\ChartObjectsLines.mqh>
#include <ChartObjects\\ChartObjectsTxtControls.mqh>
#include <Controls\\Label.mqh>
#include <Controls\\Edit.mqh>
#include <Generic\HashMap.mqh>

#define SECONDS_M1         60
#define SECONDS_M2        120
#define SECONDS_M3        180
#define SECONDS_M4        240
#define SECONDS_M5        300
#define SECONDS_M6        360
#define SECONDS_M10       600
#define SECONDS_M12       720
#define SECONDS_M15       900
#define SECONDS_M20      1200
#define SECONDS_M30      1800
#define SECONDS_H1       3600
#define SECONDS_H2       7200
#define SECONDS_H3      10800
#define SECONDS_H4      14400
#define SECONDS_H6      21600
#define SECONDS_H8      28800
#define SECONDS_H12     43200
#define SECONDS_D1      86400
#define SECONDS_W1     604800
#define SECONDS_MN1   2678400
#define SECONDS_Y1   31536000

CHashMap<ENUM_TIMEFRAMES, int> *MapTimeFrame;
CChartObjectHLine *HLines[50];
CChartObjectVLine *VLines[50];
CChartObjectRectLabel *RectFrame;
CEdit *EditCurrency;
CEdit *EditOHLC;
int currentHMode = -1;
int currentVMode = -1;
long RangeHLine[] = {10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000/*最後の要素は使われない*/};
long RangeVLine[] = {SECONDS_M10, SECONDS_H1, SECONDS_H12, SECONDS_D1, SECONDS_W1, SECONDS_MN1, SECONDS_Y1};
int HorizontalLinesWidth[] = {0, 0, 0, 0, 0, 0, 1, 1, 2, 3};
ENUM_LINE_STYLE HorizontalLinesStyle[] =  
{
   STYLE_DASHDOTDOT, STYLE_DASHDOTDOT, STYLE_DASHDOTDOT, STYLE_DASHDOTDOT, STYLE_DASHDOTDOT, STYLE_DASHDOTDOT, STYLE_DOT, STYLE_SOLID, STYLE_SOLID, STYLE_SOLID
};

int SecondsInCandle; //  ローソク足1つあたり何秒か

int OnInit()
{
   if (!CheckEnvironment(ChkExclusiveInChart, NULL, NULL, NULL, NULL))
   {
      ChartIndicatorDelete(0, 0, MQLInfoString(MQL_PROGRAM_NAME));
      return INIT_FAILED;
   }
   
   MapTimeFrame = new CHashMap<ENUM_TIMEFRAMES, int>();
   MapTimeFrame.Add(PERIOD_M1,  SECONDS_M1);
   MapTimeFrame.Add(PERIOD_M2,  SECONDS_M2);
   MapTimeFrame.Add(PERIOD_M3,  SECONDS_M3);
   MapTimeFrame.Add(PERIOD_M4,  SECONDS_M4);
   MapTimeFrame.Add(PERIOD_M5,  SECONDS_M5);
   MapTimeFrame.Add(PERIOD_M6,  SECONDS_M6);
   MapTimeFrame.Add(PERIOD_M10, SECONDS_M10);
   MapTimeFrame.Add(PERIOD_M12, SECONDS_M12);
   MapTimeFrame.Add(PERIOD_M15, SECONDS_M15);
   MapTimeFrame.Add(PERIOD_M20, SECONDS_M20);
   MapTimeFrame.Add(PERIOD_M30, SECONDS_M30);
   MapTimeFrame.Add(PERIOD_H1,  SECONDS_H1);
   MapTimeFrame.Add(PERIOD_H2,  SECONDS_H2);
   MapTimeFrame.Add(PERIOD_H3,  SECONDS_H3);
   MapTimeFrame.Add(PERIOD_H4,  SECONDS_H4);
   MapTimeFrame.Add(PERIOD_H6,  SECONDS_H6);
   MapTimeFrame.Add(PERIOD_H8,  SECONDS_H8);
   MapTimeFrame.Add(PERIOD_H12, SECONDS_H12);
   MapTimeFrame.Add(PERIOD_D1,  SECONDS_D1);
   MapTimeFrame.Add(PERIOD_W1,  SECONDS_W1);
   MapTimeFrame.Add(PERIOD_MN1, SECONDS_MN1);
   MapTimeFrame.TryGetValue(Period(), SecondsInCandle);
   
   for (int c = 0; c < ArraySize(HLines); c++)
   {
      HLines[c] = new CChartObjectHLine();   
      HLines[c].Create(0, StringFormat("GridHLine_%03d", c), 0, 0);
      HLines[c].Color((color)ChartGetInteger(0, CHART_COLOR_GRID));
      //HLines[c].Background(true);
   }
   
   for (int c = 0; c < ArraySize(VLines); c++)
   {
      VLines[c] = new CChartObjectVLine();
      VLines[c].Create(0, StringFormat("GridVLine_%03d", c), 0, 0);
      VLines[c].Color((color)ChartGetInteger(0, CHART_COLOR_GRID));
      //VLines[c].Background(true);
   }
   
   //  グローバル変数への退避
   GlobalVariableSet(StringFormat("ForegroundColor_%lld", ChartID()), (double)ChartGetInteger(0, CHART_COLOR_FOREGROUND));
   GlobalVariableSet(StringFormat("ShowGrid_%lld", ChartID()), (double)ChartGetInteger(0, CHART_SHOW_GRID));
   
   //  グリッド線の消去
   ChartSetInteger(0, CHART_SHOW_GRID, 0);
   
   RectFrame = new CChartObjectRectLabel();
   RectFrame.Create(0, "RectFrame", 0, 0, 0, 0, 0);
   RectFrame.X_Distance(0);
   RectFrame.Y_Distance(0);
   RectFrame.X_Size((int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS));
   RectFrame.Y_Size((int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 1);
   RectFrame.Fill(false);
   RectFrame.Width(1);
   RectFrame.BackColor(clrNONE);
   RectFrame.BorderType(BORDER_FLAT);
   RectFrame.Color((color)ChartGetInteger(0, CHART_COLOR_FOREGROUND));   
   ObjectSetInteger(0, "RectFrame", OBJPROP_HIDDEN, false);
   
   EditCurrency = new CEdit();
   EditCurrency.Create(0, "EditCurrency", 0, 0, 0, 0, 0);
   EditCurrency.Move(46, 3);
   EditCurrency.Size(400, 16);
   EditCurrency.FontSize(8);
   EditCurrency.ColorBorder((color)ChartGetInteger(0, CHART_COLOR_BACKGROUND));
   EditCurrency.Color((color)ChartGetInteger(0, CHART_COLOR_FOREGROUND));
   EditCurrency.ColorBackground(clrNONE);
   EditCurrency.ReadOnly(true);
   EditCurrency.Show();
   ObjectSetInteger(0, "EditCurrency", OBJPROP_HIDDEN, false);
   
   EditOHLC = new CEdit();
   EditOHLC.Create(0, "EditOHLC", 0, 0, 0, 0, 0);
   EditOHLC.Size(400, 16);
   EditOHLC.FontSize(8);
   EditOHLC.ColorBorder((color)ChartGetInteger(0, CHART_COLOR_BACKGROUND));
   EditOHLC.Color((color)ChartGetInteger(0, CHART_COLOR_FOREGROUND));
   EditOHLC.ColorBackground(clrNONE);
   EditOHLC.ReadOnly(true);
   EditOHLC.Show();
   ObjectSetInteger(0, "EditOHLC", OBJPROP_HIDDEN, false);
   
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, ChartGetInteger(0, CHART_COLOR_BACKGROUND, 0));
      
   DrawVLines();
   DrawHLines();
   DrawTexts();
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   for (int c = 0; c < ArraySize(VLines); c++)
   {
      VLines[c].Delete();
      delete VLines[c];
   }
   for (int c = 0; c < ArraySize(HLines); c++)
   {
      HLines[c].Delete();
      delete HLines[c];
   }
   EditCurrency.Destroy();
   delete EditCurrency;
   EditOHLC.Destroy();
   delete EditOHLC;
   RectFrame.Delete();
   delete RectFrame;
   delete MapTimeFrame;
   
   //  グローバル変数からの復元
   if (GlobalVariableCheck(StringFormat("ForegroundColor_%lld", ChartID())))
   {
      ChartSetInteger(0, CHART_COLOR_FOREGROUND, (long)GlobalVariableGet(StringFormat("ForegroundColor_%lld", ChartID())));
      GlobalVariableDel(StringFormat("ForegroundColor_%lld", ChartID()));
      ChartSetInteger(0, CHART_SHOW_GRID, (long)GlobalVariableGet(StringFormat("ShowGrid_%lld", ChartID())));
      GlobalVariableDel(StringFormat("ShowGrid_%lld", ChartID()));
   }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   DrawTexts();
   return rates_total;
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if (id == CHARTEVENT_CHART_CHANGE)
   {
      RectFrame.X_Size((int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS));
      RectFrame.Y_Size((int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS) - 1);
      DrawVLines();
      DrawHLines();
      ChartRedraw(0);
   }
}

void DrawHLines()
{
   //  描画の必要があるか判断する
   long min, max;
   min = (long)(ChartGetDouble(0, CHART_PRICE_MIN, 0) / Point());
   max = (long)(ChartGetDouble(0, CHART_PRICE_MAX, 0) / Point());   
   
   int d = (int)MathFloor(MathLog10(max - min));   
   min = (int)(MathFloor(min * MathPow(10, -d)) * MathPow(10, d));
   max = (int)(MathCeil(max * MathPow(10, -d)) * MathPow(10, d));   
   long h = max - min;
   
   int i;
   for (i = ArraySize(RangeHLine) - 1; i >= 0 ; i--)
   {
      if (h > RangeHLine[i]) break;
   }
   
   if (i != ArraySize(RangeHLine) - 1) i--;
   if (i < 0) i = 0;
   
   //  現在のモードと直前のモードが同じなら描画はしない
   if (currentHMode == h) return;
   currentHMode = (int)h;
   
   //  ここから描画
   for (int c = 0; c < ArraySize(HLines); c++)
   {
      HLines[c].Price(0, (double)0);
   }
   
   //  描画範囲が最大の場合は何もしない
   if (i == ArraySize(RangeHLine) - 1) return;
   
   int l = 0;   
   for (long c = min; c <= max; c += RangeHLine[0])
   {
      for (int a = ArraySize(RangeHLine) - 1; a >= i; a--)
      {
         int t = 6 - i + a;
         if (t >= ArraySize(HorizontalLinesWidth)) t = ArraySize(HorizontalLinesWidth) - 1;
         if (c % RangeHLine[a] == 0)
         {
            if (HorizontalLinesWidth[t] == 0) continue;
            HLines[l].Price(0, (double)c * Point());
            HLines[l].Style(HorizontalLinesStyle[t]);
            HLines[l].Width(HorizontalLinesWidth[t]);
            l++;
            break;
         }
      }   
   }
}

void DrawVLines()
{
   //  描画の必要があるか判断する
   datetime min, max;
   min = iTime(Symbol(), PERIOD_CURRENT, (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR));
   max = iTime(Symbol(), PERIOD_CURRENT, MathMax((int) ( ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR) - ChartGetInteger(0, CHART_WIDTH_IN_BARS) ), 0 ));
   
   int d = (int)Digits();   
   long h = max - min;
   int i;
   for (i = ArraySize(RangeVLine) - 1; i >= 0 ; i--)
   {
      if (h > RangeVLine[i]) break;
   }
   
  if (i < 0) i = 0;
   
   //  現在のモードと直前のモードが同じなら描画はしない
   if (currentHMode == h) return;
   currentHMode = (int)h;
   
   //  ここから描画
   for (int c = 0; c < ArraySize(VLines); c++)
   {
      VLines[c].Time(0, (datetime)0);
   }
   
   //  描画範囲が広範な場合は描画しない
   if (h > 15 * SECONDS_Y1) return;
   
   int l = 0;
   
   MqlDateTime dt;
   TimeToStruct(min, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   bool dl;
   if (RangeVLine[i] < SECONDS_D1)
   {
      for (int c = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR); c >= 0; c--)
      {
         TimeToStruct(iTime(Symbol(), PERIOD_CURRENT, c), dt);
         dl = false;
         if (RangeVLine[i] == SECONDS_M5 && (dt.min % 5 == 0)) dl = true;
         if (RangeVLine[i] == SECONDS_M10 && (dt.min % 10 == 0)) dl = true;
         if (RangeVLine[i] == SECONDS_M15 && (dt.min % 15 == 0)) dl = true;
         if (RangeVLine[i] == SECONDS_M30 && (dt.min % 30 == 0)) dl = true;
         if (RangeVLine[i] == SECONDS_H1 && (dt.min == 0)) dl = true;
         if (RangeVLine[i] == SECONDS_H12 && ((dt.hour == 0) || (dt.hour == 12)) && dt.min == 0 && dt.sec == 0) dl = true;            
         if (dl)
         {
            VLines[l].Time(0, iTime(Symbol(), PERIOD_CURRENT, c));
            VLines[l].Style(STYLE_DOT);
            VLines[l].Width(1);
            l++;
         }
      }
   }
   else if (RangeVLine[i] == SECONDS_D1)
   {
      for (datetime c = min; c <= max; c += SecondsInCandle)
      {
         TimeToStruct((datetime)c, dt);
         dl = false;
         //  判定条件：すべての00:00:00
         if (RangeVLine[i] == SECONDS_D1 && dt.hour == 0 && dt.min == 0 && dt.sec == 0 && ContainsTime(c)) dl = true;
         //  判定条件：すべての月曜日
         if (RangeVLine[i] == SECONDS_W1 && dt.day_of_week == 1 && dt.hour == 0 && dt.min == 0 && dt.sec == 0) dl = true;         
         if (RangeVLine[i] == SECONDS_MN1 && dt.day == 1 && dt.hour == 0 && dt.min == 0 && dt.sec == 0) dl = true;
         if (dl)
         {
            VLines[l].Time(0, c);
            VLines[l].Style(STYLE_DOT);
            VLines[l].Width(1);
            l++;
         }
      }
   }
   else if (RangeVLine[i] == SECONDS_W1)
   {
      datetime c = min;
      while(c <= max)
      {
         TimeToStruct(c, dt);
         if (dt.day_of_week == 1)
         {
            VLines[l].Time(0, c);
            VLines[l].Style(STYLE_DOT);
            VLines[l].Width(1);
            l++;
         }
         c += SECONDS_D1;
      }
   }
   else if (RangeVLine[i] == SECONDS_MN1)
   {
      dt.day = 1;
      datetime c = StructToTime(dt);
      while(c <= max)
      {
         c = StructToTime(dt);
         VLines[l].Time(0, c);
         VLines[l].Style(STYLE_DOT);
         VLines[l].Width(1);
         l++;
         if (dt.mon == 12)
         {
            dt.year++;
            dt.mon = 1;
         }
         else
         {
            dt.mon++;
         }
         c = StructToTime(dt);
      }
   }
   else
   {
      dt.mon = 1;
      dt.day = 1;
      datetime c = StructToTime(dt);
      while(c <= max)
      {
         c = StructToTime(dt);
         VLines[l].Time(0, c);
         VLines[l].Style(STYLE_DOT);
         VLines[l].Width(1);
         l++;
         dt.year++;
         c = StructToTime(dt);
      }
   }
}

void DrawTexts()
{
   EditCurrency.Text("");
   if (ChartGetInteger(0, CHART_SHOW_TICKER, 0) == true)
   {
      EditCurrency.Text(StringFormat("%s, %s: %s", Symbol(),  StringSubstr(EnumToString(Period()), 7), SymbolInfoString(Symbol(), SYMBOL_DESCRIPTION)));
   }
   
   EditOHLC.Move(46 + 8 * (StringLen(EditCurrency.Text())), 3);   
   EditOHLC.Text("");   
   if (ChartGetInteger(0, CHART_SHOW_OHLC, 0) == true)
   {
      string timeframe = StringSubstr(EnumToString(Period()), 7);
      string open = StringFormat(("%." + IntegerToString(Digits()) + "f"), iOpen(Symbol(), PERIOD_CURRENT, 0));
      string high = StringFormat("%." + IntegerToString(Digits()) + "f", iHigh(Symbol(), PERIOD_CURRENT, 0));
      string low = StringFormat("%." + IntegerToString(Digits()) + "f", iLow(Symbol(), PERIOD_CURRENT, 0));
      string close = StringFormat("%." + IntegerToString(Digits()) + "f", iClose(Symbol(), PERIOD_CURRENT, 0));
      EditOHLC.Text(StringFormat("%s %s %s %s ", open, high, low, close));
      EditOHLC.Text(EditOHLC.Text() + StringFormat("%d", iVolume(Symbol(), PERIOD_CURRENT, 0)));
   }
}

bool ContainsTime(datetime t)
{
   for (int c = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR); c >= 0; c--)
   {
      if (t == iTime(Symbol(), PERIOD_CURRENT, c)) return true;
   }
   return false;
}
