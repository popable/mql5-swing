//+------------------------------------------------------------------+
//|                                             SwingPoints.mq5      |
//|                        Copyright 2025, popable                  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- 输入参数
input int SwingPeriod = 3;     // 波段周期
input int ArrowGap = 60;       // 箭头与K线的间隔距离(点数)
input bool ShowOnlyConfirmed = true; // 只显示确认的波段点
input int MinPriceMove = 0;    // 最小价格变动(点数,0=禁用)
input bool ShowTrendLines = true;  // 显示趋势线
input bool ShowBreakoutAlerts = true; // 显示突破提醒
input bool ShowFibonacci = false;     // 显示斐波那契回调
input int MaxTrendLines = 3;          // 最大趋势线数量
input int MaxFibLevels = 2;           // 最大斐波那契回调数量
input color TrendLineColor = clrGray; // 趋势线颜色
input int TrendLineWidth = 1;         // 趋势线宽度
input bool SendAlerts = false;        // 发送提醒
input int MaxBarsToCalculate = 500;   // 最大计算K线数量

//--- 指标缓冲区
double SwingHighBuffer[];
double SwingLowBuffer[];

//--- 内部变量
int lastSwingType = 0;    // 0=无, 1=高点, -1=低点
int lastSwingIndex = -1;  // 最后一个波段点的索引
double lastSwingPrice = 0; // 最后一个波段点的价格
int secondLastSwingIndex = -1; // 倒数第二个波段点的索引
double secondLastSwingPrice = 0; // 倒数第二个波段点的价格
// 分别跟踪最后的高点和低点，用于斐波那契绘制
int lastHighIndex = -1;   // 最后一个高点的索引
double lastHighPrice = 0; // 最后一个高点的价格
int lastLowIndex = -1;    // 最后一个低点的索引
double lastLowPrice = 0;  // 最后一个低点的价格
string trendLineName = "SwingTrendLine";
string fibLevelName = "SwingFibLevel";
int trendLineCounter = 0;  // 趋势线计数器
int fibLevelCounter = 0;   // 斐波那契计数器
string lastCreatedTrendLine = ""; // 最后创建的趋势线名称
string lastCreatedFibLevel = "";  // 最后创建的斐波那契名称
double effectiveArrowGap = 0;     // 有效箭头间距
double effectiveMinPriceMove = 0; // 有效最小价格变动

//--- 绘图属性
#property indicator_label1 "Swing High"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrRed
#property indicator_width1 2

#property indicator_label2 "Swing Low"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrBlue
#property indicator_width2 2

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, SwingHighBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SwingLowBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 234); // 设置高点箭头符号（向上）
   PlotIndexSetInteger(1, PLOT_ARROW, 233); // 设置低点箭头符号（向下）
   
   // 设置空值
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   // 设置标签
   PlotIndexSetString(0, PLOT_LABEL, "Swing High");
   PlotIndexSetString(1, PLOT_LABEL, "Swing Low");
   
   // 智能计算有效的箭头间距和最小价格变动
   CalculateEffectiveValues();
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 计算有效的参数值                                                    |
//+------------------------------------------------------------------+
void CalculateEffectiveValues()
  {
   // 获取当前品种信息
   string symbol = _Symbol;
   double point = _Point;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // 打印调试信息
   Print("品种: ", symbol, ", 小数位数: ", digits, ", Point: ", point);
   Print("最大计算K线数: ", MaxBarsToCalculate);
   
   // 根据不同品种调整参数
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0) // 黄金
     {
      // 黄金：point通常是0.01，需要更小的间距
      effectiveArrowGap = ArrowGap * 0.01; // 减少到1%
      effectiveMinPriceMove = (MinPriceMove > 0) ? MinPriceMove * 0.01 : 0;
      Print("检测到黄金品种，调整参数 - ArrowGap: ", effectiveArrowGap, ", MinPriceMove: ", effectiveMinPriceMove);
     }
   else if(StringFind(symbol, "JPY") >= 0) // 日元对
     {
      // 日元对：point通常是0.001，适中调整
      effectiveArrowGap = ArrowGap * 0.1; // 减少到10%
      effectiveMinPriceMove = (MinPriceMove > 0) ? MinPriceMove * 0.1 : 0;
      Print("检测到日元品种，调整参数 - ArrowGap: ", effectiveArrowGap, ", MinPriceMove: ", effectiveMinPriceMove);
     }
   else // 其他货币对（如EURUSD）
     {
      // 标准货币对：使用原始值
      effectiveArrowGap = ArrowGap * point;
      effectiveMinPriceMove = (MinPriceMove > 0) ? MinPriceMove * point : 0;
      Print("标准货币对，使用原始参数 - ArrowGap: ", effectiveArrowGap, ", MinPriceMove: ", effectiveMinPriceMove);
     }
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // 清理所有绘制的对象
   CleanupOldObjects();
   
   // 根据卸载原因执行不同的清理操作
   switch(reason)
     {
      case REASON_REMOVE:
         Print("指标被手动移除，清理所有对象");
         break;
      case REASON_RECOMPILE:
         Print("指标重新编译，清理所有对象");
         break;
      case REASON_CHARTCHANGE:
         Print("图表切换，清理所有对象");
         break;
      case REASON_PARAMETERS:
         Print("参数修改，重新计算有效值");
         // 参数修改时重新计算有效值
         CalculateEffectiveValues();
         break;
      default:
         Print("指标卸载，清理所有对象");
         break;
     }
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   if(rates_total < SwingPeriod*2+1)
      return(0);

   // 计算有效的开始位置和限制
   int effectiveStart;
   int limit;
   
   if(prev_calculated == 0)
     {
      // 完全重新计算：从最大计算K线数开始，但不超过数据总量
      int maxStart = MathMax(0, rates_total - MaxBarsToCalculate);
      effectiveStart = MathMax(maxStart, SwingPeriod * 2);
      limit = MathMin(rates_total - SwingPeriod, rates_total);
      
      // 清空指定范围内的缓冲区
      for(int i = effectiveStart; i < rates_total; i++)
        {
         SwingHighBuffer[i] = EMPTY_VALUE;
         SwingLowBuffer[i] = EMPTY_VALUE;
        }
      
      Print("完全重新计算，范围: ", effectiveStart, " 到 ", limit, " (共 ", (limit - effectiveStart), " 根K线)");
     }
   else
     {
      // 增量计算：只计算新的K线，但限制在最大范围内
      int maxStart = MathMax(0, rates_total - MaxBarsToCalculate);
      effectiveStart = MathMax(maxStart, prev_calculated - 1);
      limit = MathMin(rates_total - SwingPeriod, rates_total);
      
      // 如果需要，清理超出范围的旧数据
      for(int i = 0; i < maxStart && i < rates_total; i++)
        {
         SwingHighBuffer[i] = EMPTY_VALUE;
         SwingLowBuffer[i] = EMPTY_VALUE;
        }
     }
   
   // 初始化缓冲区为空值
   if(prev_calculated == 0)
     {
      ArrayInitialize(SwingHighBuffer, EMPTY_VALUE);
      ArrayInitialize(SwingLowBuffer, EMPTY_VALUE);
      lastSwingType = 0;
      lastSwingIndex = -1;
      lastSwingPrice = 0;
      secondLastSwingIndex = -1;
      secondLastSwingPrice = 0;
      lastHighIndex = -1;
      lastHighPrice = 0;
      lastLowIndex = -1;
      lastLowPrice = 0;
      trendLineCounter = 0;
      fibLevelCounter = 0;
      lastCreatedTrendLine = "";
      lastCreatedFibLevel = "";
      
      // 重新计算有效值（防止品种切换）
      CalculateEffectiveValues();
      
      // 清理之前的对象（只在完全重新初始化时执行）
      CleanupOldObjects();
      
      // 需要重新搜索最近的波段点作为起始点
      FindRecentSwingPoints(effectiveStart, rates_total, high, low);
     }
   
   // 检测波段高低点 (交替出现版本) - 限制在有效范围内
   int processedBars = 0;
   datetime startTime = TimeCurrent();
   
   for(int i = effectiveStart; i < limit; i++)
     {
      // 确保有足够的历史数据进行检查
      if(i < SwingPeriod * 2)
         continue;
      
      processedBars++;
      
      // 检查 SwingPeriod 根K线之前的位置作为候选点
      int checkIndex = i - SwingPeriod;
      
      bool isHigh = true;
      bool isLow = true;
      double curHigh = high[checkIndex];
      double curLow = low[checkIndex];

      // 只检查历史数据：左右各SwingPeriod根K线
      for(int j = 1; j <= SwingPeriod; j++)
        {
         // 检查左边的历史数据
         if(high[checkIndex - j] >= curHigh)
            isHigh = false;
         if(low[checkIndex - j] <= curLow)
            isLow = false;
            
         // 检查右边的历史数据（现在都是历史数据了）
         if(high[checkIndex + j] >= curHigh)
            isHigh = false;
         if(low[checkIndex + j] <= curLow)
            isLow = false;
        }

      // 可选的最小价格变动过滤
      if(effectiveMinPriceMove > 0)
        {
         if(isHigh)
           {
            double minHighAround = curHigh;
            for(int j = 1; j <= SwingPeriod; j++)
              {
               if(high[checkIndex - j] < minHighAround) minHighAround = high[checkIndex - j];
               if(high[checkIndex + j] < minHighAround) minHighAround = high[checkIndex + j];
              }
            if((curHigh - minHighAround) < effectiveMinPriceMove)
               isHigh = false;
           }
         
         if(isLow)
           {
            double maxLowAround = curLow;
            for(int j = 1; j <= SwingPeriod; j++)
              {
               if(low[checkIndex - j] > maxLowAround) maxLowAround = low[checkIndex - j];
               if(low[checkIndex + j] > maxLowAround) maxLowAround = low[checkIndex + j];
              }
            if((maxLowAround - curLow) < effectiveMinPriceMove)
               isLow = false;
           }
        }

      // 交替逻辑：确保波段点交替出现
      if(isHigh && isLow)
        {
         // 如果同时是高点和低点，选择与上一个相反的类型
         if(lastSwingType == 1) // 上一个是高点，这次选低点
           {
            isHigh = false;
           }
         else if(lastSwingType == -1) // 上一个是低点，这次选高点
           {
            isLow = false;
           }
         else // 如果是第一个点，选择更突出的那个
           {
            double highStrength = 0;
            double lowStrength = 0;
            
            // 计算高点强度
            for(int j = 1; j <= SwingPeriod; j++)
              {
               highStrength += (curHigh - high[checkIndex - j]) + (curHigh - high[checkIndex + j]);
              }
            
            // 计算低点强度  
            for(int j = 1; j <= SwingPeriod; j++)
              {
               lowStrength += (low[checkIndex - j] - curLow) + (low[checkIndex + j] - curLow);
              }
            
            if(highStrength > lowStrength)
               isLow = false;
            else
               isHigh = false;
           }
        }
      
      // 交替检查：防止连续相同类型的波段点
      if(isHigh && lastSwingType == 1)
        {
         // 如果当前是高点，但上一个也是高点
         if(curHigh > lastSwingPrice)
           {
            // 当前高点更高，替换上一个高点
            if(lastSwingIndex >= 0)
               SwingHighBuffer[lastSwingIndex] = EMPTY_VALUE;
            // 同时更新高点跟踪
            lastHighIndex = checkIndex;
            lastHighPrice = curHigh;
           }
         else
           {
            // 当前高点更低，忽略当前高点
            isHigh = false;
           }
        }
      
      if(isLow && lastSwingType == -1)
        {
         // 如果当前是低点，但上一个也是低点
         if(curLow < lastSwingPrice)
           {
            // 当前低点更低，替换上一个低点
            if(lastSwingIndex >= 0)
               SwingLowBuffer[lastSwingIndex] = EMPTY_VALUE;
            // 同时更新低点跟踪
            lastLowIndex = checkIndex;
            lastLowPrice = curLow;
           }
         else
           {
            // 当前低点更高，忽略当前低点
            isLow = false;
           }
        }

      // 设置箭头位置
      if(isHigh)
        {
         SwingHighBuffer[checkIndex] = curHigh + effectiveArrowGap;
         
         // 更新波段点信息
         secondLastSwingIndex = lastSwingIndex;
         secondLastSwingPrice = lastSwingPrice;
         lastSwingType = 1;
         lastSwingIndex = checkIndex;
         lastSwingPrice = curHigh;
         
         // 更新最后的高点信息
         lastHighIndex = checkIndex;
         lastHighPrice = curHigh;
         
         // 绘制趋势线和工具 - 斐波那契需要一个高点和一个低点
         if(secondLastSwingIndex >= 0)
           {
            DrawTradingTools(checkIndex, curHigh, secondLastSwingIndex, secondLastSwingPrice, true, time);
           }
        }
      else if(isLow)
        {
         SwingLowBuffer[checkIndex] = curLow - effectiveArrowGap;
         
         // 更新波段点信息
         secondLastSwingIndex = lastSwingIndex;
         secondLastSwingPrice = lastSwingPrice;
         lastSwingType = -1;
         lastSwingIndex = checkIndex;
         lastSwingPrice = curLow;
         
         // 更新最后的低点信息
         lastLowIndex = checkIndex;
         lastLowPrice = curLow;
         
         // 绘制趋势线和工具 - 斐波那契需要一个高点和一个低点
         if(secondLastSwingIndex >= 0)
           {
            DrawTradingTools(checkIndex, curLow, secondLastSwingIndex, secondLastSwingPrice, false, time);
           }
        }
     }

   // 打印性能信息
   datetime endTime = TimeCurrent();
   if(processedBars > 0)
     {
      Print("处理了 ", processedBars, " 根K线，用时 ", (endTime - startTime), " 秒");
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| 查找最近的波段点作为起始参考                                          |
//+------------------------------------------------------------------+
void FindRecentSwingPoints(int startIndex, int endIndex, const double &high[], const double &low[])
  {
   // 在限定范围内向前搜索，找到最近的两个波段点
   int foundCount = 0;
   int foundIndices[2];
   int foundTypes[2]; // 1=高点, -1=低点
   double foundPrices[2];
   
   // 从后往前搜索波段点
   for(int i = endIndex - SwingPeriod - 1; i >= startIndex + SwingPeriod && foundCount < 2; i--)
     {
      bool isHigh = true;
      bool isLow = true;
      double curHigh = high[i];
      double curLow = low[i];

      // 检查是否为波段高低点
      for(int j = 1; j <= SwingPeriod; j++)
        {
         if(i - j >= 0 && high[i - j] >= curHigh) isHigh = false;
         if(i - j >= 0 && low[i - j] <= curLow) isLow = false;
         if(i + j < endIndex && high[i + j] >= curHigh) isHigh = false;
         if(i + j < endIndex && low[i + j] <= curLow) isLow = false;
        }

      // 如果找到波段点，记录下来
      if(isHigh || isLow)
        {
         foundIndices[foundCount] = i;
         if(isHigh && !isLow)
           {
            foundTypes[foundCount] = 1;
            foundPrices[foundCount] = curHigh;
           }
         else if(isLow && !isHigh)
           {
            foundTypes[foundCount] = -1;
            foundPrices[foundCount] = curLow;
           }
         else if(isHigh && isLow)
           {
            // 如果同时是高点和低点，选择更突出的
            double highStrength = 0;
            double lowStrength = 0;
            
            for(int j = 1; j <= SwingPeriod; j++)
              {
               if(i - j >= 0) highStrength += (curHigh - high[i - j]);
               if(i + j < endIndex) highStrength += (curHigh - high[i + j]);
               if(i - j >= 0) lowStrength += (low[i - j] - curLow);
               if(i + j < endIndex) lowStrength += (low[i + j] - curLow);
              }
            
            if(highStrength > lowStrength)
              {
               foundTypes[foundCount] = 1;
               foundPrices[foundCount] = curHigh;
              }
            else
              {
               foundTypes[foundCount] = -1;
               foundPrices[foundCount] = curLow;
              }
           }
         foundCount++;
        }
     }
   
   // 设置找到的波段点信息
   if(foundCount >= 1)
     {
      lastSwingIndex = foundIndices[0];
      lastSwingType = foundTypes[0];
      lastSwingPrice = foundPrices[0];
      
      // 初始化高点和低点跟踪
      if(foundTypes[0] == 1) // 最后一个是高点
        {
         lastHighIndex = foundIndices[0];
         lastHighPrice = foundPrices[0];
        }
      else // 最后一个是低点
        {
         lastLowIndex = foundIndices[0];
         lastLowPrice = foundPrices[0];
        }
      
      if(foundCount >= 2)
        {
         secondLastSwingIndex = foundIndices[1];
         secondLastSwingPrice = foundPrices[1];
         
         // 设置另一个类型的点
         if(foundTypes[1] == 1) // 倒数第二个是高点
           {
            lastHighIndex = foundIndices[1];
            lastHighPrice = foundPrices[1];
           }
         else // 倒数第二个是低点
           {
            lastLowIndex = foundIndices[1];
            lastLowPrice = foundPrices[1];
           }
        }
      
      Print("找到最近波段点 - 最后: 索引", lastSwingIndex, ", 类型", lastSwingType, ", 价格", lastSwingPrice,
            foundCount >= 2 ? StringFormat(", 倒数第二: 索引%d, 价格%.5f", secondLastSwingIndex, secondLastSwingPrice) : "");
      Print("高点跟踪: 索引", lastHighIndex, ", 价格", lastHighPrice);
      Print("低点跟踪: 索引", lastLowIndex, ", 价格", lastLowPrice);
     }
   else
     {
      Print("在指定范围内未找到波段点，将从头开始计算");
     }
  }
//+------------------------------------------------------------------+
//| 绘制交易工具函数                                                    |
//+------------------------------------------------------------------+
void DrawTradingTools(int currentIndex, double currentPrice, int lastIndex, double lastPrice, bool isHigh, const datetime &time[])
  {
   // 使用传入的time数组获取时间
   datetime currentTime = time[currentIndex];
   datetime lastTime = time[lastIndex];
   
   // 绘制趋势线
   if(ShowTrendLines)
     {
      // 使用波段点索引作为唯一标识符，避免重复创建
      string lineName = trendLineName + "_" + IntegerToString(lastIndex) + "_" + IntegerToString(currentIndex);
      
      // 检查对象是否已存在，避免重复创建
      if(ObjectFind(0, lineName) < 0)
        {
         if(ObjectCreate(0, lineName, OBJ_TREND, 0, lastTime, lastPrice, currentTime, currentPrice))
           {
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, TrendLineColor);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, TrendLineWidth);
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
            
            // 删除上一条趋势线，保持只显示最新的
            if(lastCreatedTrendLine != "" && lastCreatedTrendLine != lineName)
              {
               ObjectDelete(0, lastCreatedTrendLine);
              }
            
            lastCreatedTrendLine = lineName;
            trendLineCounter++;
            
            // 清理过多的旧趋势线
            if(trendLineCounter > MaxTrendLines)
              {
               CleanupOldTrendLines();
              }
           }
        }
     }
   
   // 检查趋势线突破
   if(ShowBreakoutAlerts)
     {
      CheckBreakout(currentIndex, currentPrice, lastIndex, lastPrice, isHigh);
     }
   
   // 绘制斐波那契回调 - 确保使用一个高点和一个低点
   if(ShowFibonacci)
     {
      DrawFibonacci(time);
     }
  }

//+------------------------------------------------------------------+
//| 检查趋势线突破                                                      |
//+------------------------------------------------------------------+
void CheckBreakout(int currentIndex, double currentPrice, int lastIndex, double lastPrice, bool isHigh)
  {
   // 获取最新的收盘价 (使用0索引获取最新价格)
   double currentClose = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // 计算趋势线在当前位置的价格
   double trendLinePrice = CalculateTrendLinePrice(lastIndex, lastPrice, currentIndex, currentPrice, 0);
   
   bool breakout = false;
   string message = "";
   
   if(isHigh) // 下降趋势线
     {
      if(currentClose > trendLinePrice)
        {
         breakout = true;
         message = "突破下降趋势线 - 看涨信号";
        }
     }
   else // 上升趋势线
     {
      if(currentClose < trendLinePrice)
        {
         breakout = true;
         message = "跌破上升趋势线 - 看跌信号";
        }
     }
   
   if(breakout && SendAlerts)
     {
      Alert(message + " - " + _Symbol);
     }
  }

//+------------------------------------------------------------------+
//| 计算趋势线价格                                                      |
//+------------------------------------------------------------------+
double CalculateTrendLinePrice(int x1, double y1, int x2, double y2, int targetIndex)
  {
   if(x1 == x2) return y1;
   
   double slope = (y2 - y1) / (x2 - x1);
   return y1 + slope * (targetIndex - x1);
  }

//+------------------------------------------------------------------+
//| 绘制斐波那契回调                                                    |
//+------------------------------------------------------------------+
void DrawFibonacci(const datetime &time[])
  {
   // 确保我们有一个高点和一个低点
   if(lastHighIndex < 0 || lastLowIndex < 0)
      return;
   
   // 使用最后的高点和低点索引作为唯一标识符
   string fibName = fibLevelName + "_" + IntegerToString(lastHighIndex) + "_" + IntegerToString(lastLowIndex);
   
   datetime highTime = time[lastHighIndex];
   datetime lowTime = time[lastLowIndex];
   
   // 检查对象是否已存在，避免重复创建
   if(ObjectFind(0, fibName) < 0)
     {
      // 斐波那契回调线从高点到低点绘制
      if(ObjectCreate(0, fibName, OBJ_FIBO, 0, highTime, lastHighPrice, lowTime, lastLowPrice))
        {
         ObjectSetInteger(0, fibName, OBJPROP_COLOR, clrGoldenrod);
         ObjectSetInteger(0, fibName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, fibName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, fibName, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, fibName, OBJPROP_BACK, false);
         
         // 设置斐波那契水平数量
         ObjectSetInteger(0, fibName, OBJPROP_LEVELS, 5);
         
         // 批量设置斐波那契水平：显示0, 0.236, 0.382, 0.618, 1.0
         double levels[5] = {0.0, 0.236, 0.382, 0.618, 1.0};
         string texts[5] = {"0% (High)", "23.6%", "38.2%", "61.8%", "100% (Low)"};
         
         for(int i = 0; i < 5; i++)
           {
            ObjectSetDouble(0, fibName, OBJPROP_LEVELVALUE, i, levels[i]);
            ObjectSetString(0, fibName, OBJPROP_LEVELTEXT, i, texts[i]);
            ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, i, clrGoldenrod);
            ObjectSetInteger(0, fibName, OBJPROP_LEVELSTYLE, i, STYLE_DOT);
            ObjectSetInteger(0, fibName, OBJPROP_LEVELWIDTH, i, 1);
            ObjectSetInteger(0, fibName, OBJPROP_ALIGN, i, ALIGN_LEFT);
           }
         
         // 删除上一个斐波那契回调，保持只显示最新的
         if(lastCreatedFibLevel != "" && lastCreatedFibLevel != fibName)
           {
            ObjectDelete(0, lastCreatedFibLevel);
           }
         
         lastCreatedFibLevel = fibName;
         fibLevelCounter++;
         
         // 清理过多的旧斐波那契回调
         if(fibLevelCounter > MaxFibLevels)
           {
            CleanupOldFibLevels();
           }
           
         Print("绘制斐波那契回调：高点[", lastHighIndex, "] ", lastHighPrice, " -> 低点[", lastLowIndex, "] ", lastLowPrice);
        }
     }
  }

//+------------------------------------------------------------------+
//| 获取当前趋势方向                                                    |
//+------------------------------------------------------------------+
int GetTrendDirection()
  {
   if(lastSwingIndex >= 0 && secondLastSwingIndex >= 0)
     {
      if(lastSwingType == 1) // 最后是高点
        {
         return (lastSwingPrice > secondLastSwingPrice) ? 1 : -1; // 上升或下降
        }
      else // 最后是低点
        {
         return (lastSwingPrice < secondLastSwingPrice) ? -1 : 1; // 下降或上升
        }
     }
   return 0; // 无趋势
  }

//+------------------------------------------------------------------+
//| 获取支撑阻力位                                                      |
//+------------------------------------------------------------------+
double GetSupportResistance(bool getSupport)
  {
   if(lastSwingIndex >= 0)
     {
      if(getSupport)
        {
         return (lastSwingType == -1) ? lastSwingPrice : secondLastSwingPrice;
        }
      else
        {
         return (lastSwingType == 1) ? lastSwingPrice : secondLastSwingPrice;
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+
//| 清理旧对象函数                                                      |
//+------------------------------------------------------------------+
void CleanupOldObjects()
  {
   // 使用更高效的对象删除方法
   int totalObjects = ObjectsTotal(0);
   string objectsToDelete[];
   int deleteCount = 0;
   
   // 先收集需要删除的对象名称
   for(int i = 0; i < totalObjects; i++)
     {
      string objName = ObjectName(0, i);
      if(StringFind(objName, trendLineName) >= 0 || StringFind(objName, fibLevelName) >= 0)
        {
         ArrayResize(objectsToDelete, deleteCount + 1);
         objectsToDelete[deleteCount] = objName;
         deleteCount++;
        }
     }
   
   // 批量删除对象
   for(int i = 0; i < deleteCount; i++)
     {
      ObjectDelete(0, objectsToDelete[i]);
     }
   
   // 只在有对象删除时才刷新图表
   if(deleteCount > 0)
     {
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//| 清理旧趋势线                                                        |
//+------------------------------------------------------------------+
void CleanupOldTrendLines()
  {
   int totalObjects = ObjectsTotal(0);
   string trendLineObjects[];
   int trendLineCount = 0;
   
   // 收集所有趋势线对象
   for(int i = 0; i < totalObjects; i++)
     {
      string objName = ObjectName(0, i);
      if(StringFind(objName, trendLineName) >= 0)
        {
         ArrayResize(trendLineObjects, trendLineCount + 1);
         trendLineObjects[trendLineCount] = objName;
         trendLineCount++;
        }
     }
   
   // 如果趋势线数量超过最大值，删除最老的
   if(trendLineCount > MaxTrendLines)
     {
      int deleteCount = trendLineCount - MaxTrendLines;
      for(int i = 0; i < deleteCount; i++)
        {
         ObjectDelete(0, trendLineObjects[i]);
        }
     }
  }

//+------------------------------------------------------------------+
//| 清理旧斐波那契回调                                                  |
//+------------------------------------------------------------------+
void CleanupOldFibLevels()
  {
   int totalObjects = ObjectsTotal(0);
   string fibObjects[];
   int fibCount = 0;
   
   // 收集所有斐波那契对象
   for(int i = 0; i < totalObjects; i++)
     {
      string objName = ObjectName(0, i);
      if(StringFind(objName, fibLevelName) >= 0)
        {
         ArrayResize(fibObjects, fibCount + 1);
         fibObjects[fibCount] = objName;
         fibCount++;
        }
     }
   
   // 如果斐波那契数量超过最大值，删除最老的
   if(fibCount > MaxFibLevels)
     {
      int deleteCount = fibCount - MaxFibLevels;
      for(int i = 0; i < deleteCount; i++)
        {
         ObjectDelete(0, fibObjects[i]);
        }
     }
  }
//+------------------------------------------------------------------+
