//+------------------------------------------------------------------+
//|                                             SwingPoints.mq5      |
//|                        Copyright 2025, popable                  |
//|                        快速高低点检测指标                          |
//|                        支持快速模式和确认模式                      |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- 输入参数
input int SwingPeriod = 3;     // 波段周期
input int ArrowGap = 60;       // 箭头与K线的间隔距离(点数)
input bool ShowOnlyConfirmed = false; // 只显示确认的波段点（false=快速模式，true=确认模式）
input int ConfirmationBars = 1; // 确认K线数量（仅在确认模式下生效）
input bool UltraFastMode = false; // 超快速模式（实时检测，可能产生假信号）
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
input bool OptimizeDrawing = true;    // 优化绘制性能（只在波段点更新时重绘）
input bool ShowPrevHighLow = true;    // 显示前期高低点水平线
input color PrevHighColor = clrRed;   // 前期高点线颜色
input color PrevLowColor = clrBlue;   // 前期低点线颜色
input int PrevLineWidth = 1;          // 前期高低点线宽度
input ENUM_LINE_STYLE PrevLineStyle = STYLE_DASH; // 前期高低点线样式
input bool ShowHighTopLine = true;    // 显示高点顶部射线
input bool ShowLowBottomLine = true;  // 显示低点底部射线
input color HighTopColor = clrOrange; // 高点顶部射线颜色
input color LowBottomColor = clrLime; // 低点底部射线颜色
input int TopBottomLineWidth = 2;     // 顶部底部射线宽度
input ENUM_LINE_STYLE TopBottomLineStyle = STYLE_SOLID; // 顶部底部射线样式
// --- 新增：高低点关系标签参数
input bool ShowSwingRelationLabels = true;  // 显示摆动点关系标签
input color HigherHighColor = clrLime;       // Higher High标签颜色
input color LowerHighColor = clrRed;         // Lower High标签颜色
input color HigherLowColor = clrGreen;       // Higher Low标签颜色
input color LowerLowColor = clrMaroon;       // Lower Low标签颜色
input int LabelFontSize = 8;                 // 标签字体大小
input string LabelFont = "Arial";            // 标签字体
// --- 新增：趋势分析参数
input bool ShowTrendAnalysis = true;         // 显示趋势分析
input int TrendAnalysisPeriod = 4;           // 趋势分析周期（使用最近N个摆动点）
input color UpTrendColor = clrLime;          // 上升趋势颜色
input color DownTrendColor = clrRed;         // 下降趋势颜色
input color RangeColor = clrYellow;          // 交易区间颜色
input int TrendLabelFontSize = 12;           // 趋势标签字体大小

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
bool newSwingPointFound = false;  // 是否发现新的波段点
// 前期高低点追踪变量
double prevHighPrice = 0;         // 前期高点价格（最近两个高点中较高的）
double prevLowPrice = 0;          // 前期低点价格（最近两个低点中较低的）
int highPointsFound = 0;          // 已找到的高点数量
int lowPointsFound = 0;           // 已找到的低点数量
double recentHighs[2];            // 最近两个高点价格
double recentLows[2];             // 最近两个低点价格
string prevHighLineName = "PrevHighLine"; // 前期高点线名称
string prevLowLineName = "PrevLowLine";   // 前期低点线名称
// 扩展高低点跟踪，用于绘制射线
double allRecentHighs[4];         // 最近四个高点价格
double allRecentLows[4];          // 最近四个低点价格
int allRecentHighsIndices[4];     // 最近四个高点索引
int allRecentLowsIndices[4];      // 最近四个低点索引
int totalHighsFound = 0;          // 总高点数量
int totalLowsFound = 0;           // 总低点数量
string highTopLineName = "HighTopLine";   // 高点顶部射线名称
string lowBottomLineName = "LowBottomLine"; // 低点底部射线名称

// --- 新增：摆动点关系跟踪变量
struct SwingPointData
  {
   double price;         // 价格
   int index;           // K线索引
   datetime time;       // 时间
   string relation;     // 关系：HH, LH, HL, LL
  };

SwingPointData lastHighPoint;      // 上一个高点
SwingPointData lastLowPoint;       // 上一个低点
SwingPointData secondLastHighPoint; // 上上个高点
SwingPointData secondLastLowPoint;  // 上上个低点
string relationLabelPrefix = "SwingRelation_"; // 关系标签前缀
int labelCounter = 0;              // 标签计数器

// --- 新增：趋势分析变量
enum TREND_STATE
  {
   TREND_UP,      // 上升趋势
   TREND_DOWN,    // 下降趋势
   TREND_RANGE    // 交易区间
  };

TREND_STATE currentTrend = TREND_RANGE;  // 当前趋势状态
string trendLabelName = "TrendAnalysis"; // 趋势分析标签名称
SwingPointData swingHistory[8];          // 摆动点历史记录（高点和低点混合）
int swingHistoryCount = 0;               // 摆动点历史数量

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
   
   // 初始化摆动点关系跟踪结构
   InitializeSwingPointData(lastHighPoint);
   InitializeSwingPointData(lastLowPoint);
   InitializeSwingPointData(secondLastHighPoint);
   InitializeSwingPointData(secondLastLowPoint);
   labelCounter = 0;
   
   // 初始化趋势分析变量
   currentTrend = TREND_RANGE;
   swingHistoryCount = 0;
   for(int i = 0; i < 8; i++)
     {
      InitializeSwingPointData(swingHistory[i]);
     }
   
   // 在快速模式下启动定时器以确保实时更新
   if(!ShowOnlyConfirmed || UltraFastMode)
     {
      EventSetTimer(1); // 每秒检查一次
     }
   
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
   // 停止定时器
   EventKillTimer();
   
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
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   // 在快速模式下，定期触发图表重绘以确保实时更新
   if(!ShowOnlyConfirmed || UltraFastMode)
     {
      ChartRedraw(0);
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
      // 修复：确保能处理到最新的K线
      if(UltraFastMode)
         limit = rates_total; // 超快速模式处理到当前K线
      else
         limit = rates_total - 1; // 其他模式处理到前一根完整K线
      
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
      effectiveStart = MathMax(maxStart, prev_calculated - 2); // 向前多检查一根K线
      // 修复：确保能处理到最新的K线
      if(UltraFastMode)
         limit = rates_total; // 超快速模式处理到当前K线
      else
         limit = rates_total - 1; // 其他模式处理到前一根完整K线
      
      // 如果需要，清理超出范围的旧数据，但不要清理即将计算的范围
      for(int i = 0; i < maxStart && i < effectiveStart; i++)
        {
         SwingHighBuffer[i] = EMPTY_VALUE;
         SwingLowBuffer[i] = EMPTY_VALUE;
        }
        
      // 只清空最近几根K线的缓冲区，以便重新计算
      for(int i = MathMax(0, prev_calculated - 3); i < rates_total; i++)
        {
         if(i >= effectiveStart)
           {
            SwingHighBuffer[i] = EMPTY_VALUE;
            SwingLowBuffer[i] = EMPTY_VALUE;
           }
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
      newSwingPointFound = false;
      // 初始化前期高低点变量
      prevHighPrice = 0;
      prevLowPrice = 0;
      highPointsFound = 0;
      lowPointsFound = 0;
      ArrayInitialize(recentHighs, 0);
      ArrayInitialize(recentLows, 0);
      // 初始化扩展高低点跟踪
      totalHighsFound = 0;
      totalLowsFound = 0;
      ArrayInitialize(allRecentHighs, 0);
      ArrayInitialize(allRecentLows, 0);
      ArrayInitialize(allRecentHighsIndices, -1);
      ArrayInitialize(allRecentLowsIndices, -1);
      // 初始化摆动点关系跟踪
      InitializeSwingPointData(lastHighPoint);
      InitializeSwingPointData(lastLowPoint);
      InitializeSwingPointData(secondLastHighPoint);
      InitializeSwingPointData(secondLastLowPoint);
      labelCounter = 0;
      
      // 初始化趋势分析
      currentTrend = TREND_RANGE;
      swingHistoryCount = 0;
      for(int i = 0; i < 8; i++)
        {
         InitializeSwingPointData(swingHistory[i]);
        }
      
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
   newSwingPointFound = false; // 重置标志
   
   for(int i = effectiveStart; i < limit; i++)
     {
      // 确保有足够的历史数据进行检查
      if(i < SwingPeriod * 2)
         continue;
      
      processedBars++;
      
      // 根据模式决定检查位置
      int checkIndex;
      if(ShowOnlyConfirmed)
        {
         // 确认模式：检查 ConfirmationBars 根K线之前的位置作为候选点
         checkIndex = i - ConfirmationBars;
         if(checkIndex < SwingPeriod)
            continue;
        }
      else if(UltraFastMode)
        {
         // 超快速模式：检查当前K线（实时模式）
         checkIndex = i;
         if(checkIndex < SwingPeriod)
            continue;
        }
      else
        {
         // 快速模式：检查前一根完整的K线
         checkIndex = i - 1;
         if(checkIndex < SwingPeriod)
            continue;
        }
      
      bool isHigh = true;
      bool isLow = true;
      double curHigh = high[checkIndex];
      double curLow = low[checkIndex];

      // 检查左右各SwingPeriod根K线，根据模式调整右侧检查范围
      for(int j = 1; j <= SwingPeriod; j++)
        {
         // 检查左边的历史数据
         if(checkIndex - j >= 0)
           {
            if(high[checkIndex - j] >= curHigh)
               isHigh = false;
            if(low[checkIndex - j] <= curLow)
               isLow = false;
           }
            
         // 检查右边的数据
         if(ShowOnlyConfirmed)
           {
            // 确认模式：检查右边的历史数据
            if(checkIndex + j < rates_total)
              {
               if(high[checkIndex + j] >= curHigh)
                  isHigh = false;
               if(low[checkIndex + j] <= curLow)
                  isLow = false;
              }
           }
         else if(UltraFastMode)
           {
            // 超快速模式：只检查左侧历史数据，不等待右侧确认
            // 这样可以实现最快的响应，但可能产生假信号
            }
         else
           {
            // 快速模式：减少右侧检查范围
            int rightCheckLimit = MathMin(j, i - checkIndex - 1);
            if(rightCheckLimit > 0 && checkIndex + rightCheckLimit < rates_total)
              {
               if(high[checkIndex + rightCheckLimit] >= curHigh)
                  isHigh = false;
               if(low[checkIndex + rightCheckLimit] <= curLow)
                  isLow = false;
              }
           }
        }

      // 可选的最小价格变动过滤
      if(effectiveMinPriceMove > 0)
        {
         if(isHigh)
           {
            double minHighAround = curHigh;
            for(int j = 1; j <= SwingPeriod; j++)
              {
               if(checkIndex - j >= 0 && high[checkIndex - j] < minHighAround) 
                  minHighAround = high[checkIndex - j];
               
               if(ShowOnlyConfirmed)
                 {
                  if(checkIndex + j < rates_total && high[checkIndex + j] < minHighAround) 
                     minHighAround = high[checkIndex + j];
                 }
               else if(UltraFastMode)
                 {
                  // 超快速模式：只使用左侧数据
                  }
               else
                 {
                  int rightCheckLimit = MathMin(j, i - checkIndex - 1);
                  if(rightCheckLimit > 0 && checkIndex + rightCheckLimit < rates_total && 
                     high[checkIndex + rightCheckLimit] < minHighAround)
                     minHighAround = high[checkIndex + rightCheckLimit];
                 }
              }
            if((curHigh - minHighAround) < effectiveMinPriceMove)
               isHigh = false;
           }
         
         if(isLow)
           {
            double maxLowAround = curLow;
            for(int j = 1; j <= SwingPeriod; j++)
              {
               if(checkIndex - j >= 0 && low[checkIndex - j] > maxLowAround) 
                  maxLowAround = low[checkIndex - j];
               
               if(ShowOnlyConfirmed)
                 {
                  if(checkIndex + j < rates_total && low[checkIndex + j] > maxLowAround) 
                     maxLowAround = low[checkIndex + j];
                 }
               else if(UltraFastMode)
                 {
                  // 超快速模式：只使用左侧数据
                  }
               else
                 {
                  int rightCheckLimit = MathMin(j, i - checkIndex - 1);
                  if(rightCheckLimit > 0 && checkIndex + rightCheckLimit < rates_total && 
                     low[checkIndex + rightCheckLimit] > maxLowAround)
                     maxLowAround = low[checkIndex + rightCheckLimit];
                 }
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
      
      //=================================================================
      // 连续波段点去重处理
      // 改进说明：
      // 1. 将去重逻辑独立成专门的函数，代码更清晰
      // 2. 增加详细的日志输出，便于调试和监控
      // 3. 安全的数组更新机制，避免数据不一致
      // 4. 明确的返回值判断，逻辑更可靠
      //=================================================================
      
      // 连续高点去重：防止连续的高点
      if(isHigh && lastSwingType == 1)
        {
         // 如果当前是高点，但上一个也是高点，进行去重处理
         if(ProcessConsecutiveHighPoints(curHigh, checkIndex))
           {
            // 当前高点更优，已经替换了上一个高点
            // 更新摆动点历史记录中的最新高点并重新分析趋势
            if(swingHistoryCount > 0 && swingHistory[0].relation == "H")
              {
               swingHistory[0].price = curHigh;
               swingHistory[0].index = checkIndex;
               swingHistory[0].time = time[checkIndex];
               
               if(ShowTrendAnalysis)
                 {
                  AnalyzeTrend();
                  UpdateTrendLabel();
                 }
              }
           }
         else
           {
            // 当前高点不如上一个，忽略当前高点
            isHigh = false;
           }
        }
      
      // 连续低点去重：防止连续的低点
      if(isLow && lastSwingType == -1)
        {
         // 如果当前是低点，但上一个也是低点，进行去重处理
         if(ProcessConsecutiveLowPoints(curLow, checkIndex))
           {
            // 当前低点更优，已经替换了上一个低点
            // 更新摆动点历史记录中的最新低点并重新分析趋势
            if(swingHistoryCount > 0 && swingHistory[0].relation == "L")
              {
               swingHistory[0].price = curLow;
               swingHistory[0].index = checkIndex;
               swingHistory[0].time = time[checkIndex];
               
               if(ShowTrendAnalysis)
                 {
                  AnalyzeTrend();
                  UpdateTrendLabel();
                 }
              }
           }
         else
           {
            // 当前低点不如上一个，忽略当前低点
            isLow = false;
           }
        }

      // 设置箭头位置
      if(isHigh)
        {
         SwingHighBuffer[checkIndex] = curHigh + effectiveArrowGap;
         
         // 检查是否是连续高点替换模式
         bool isConsecutiveHighReplacement = (lastSwingType == 1);
         
         // 计算高点关系并创建标签
         string highRelation = "";
         if(ShowSwingRelationLabels)
           {
            highRelation = CalculateHighRelation(curHigh, checkIndex, time);
           }
         
         // 更新波段点信息（只有在非替换模式下才更新secondLast）
         if(!isConsecutiveHighReplacement)
           {
            secondLastSwingIndex = lastSwingIndex;
            secondLastSwingPrice = lastSwingPrice;
           }
         
         lastSwingType = 1;
         lastSwingIndex = checkIndex;
         lastSwingPrice = curHigh;
         
         // 更新最后的高点信息
         lastHighIndex = checkIndex;
         lastHighPrice = curHigh;
         newSwingPointFound = true;
         
         // 更新前期高点跟踪
         UpdatePrevHighPoints(curHigh);
         
         // 只有在非替换模式下才添加到扩展高点跟踪数组
         if(!isConsecutiveHighReplacement)
           {
            UpdateAllHighPoints(curHigh, checkIndex);
           }
         
         // 添加到摆动点历史记录并进行趋势分析
         if(!isConsecutiveHighReplacement)
           {
            AddToSwingHistory(curHigh, checkIndex, time[checkIndex], true);
            if(ShowTrendAnalysis)
              {
               AnalyzeTrend();
               UpdateTrendLabel();
              }
           }
        }
      else if(isLow)
        {
         SwingLowBuffer[checkIndex] = curLow - effectiveArrowGap;
         
         // 检查是否是连续低点替换模式
         bool isConsecutiveLowReplacement = (lastSwingType == -1);
         
         // 计算低点关系并创建标签
         string lowRelation = "";
         if(ShowSwingRelationLabels)
           {
            lowRelation = CalculateLowRelation(curLow, checkIndex, time);
           }
         
         // 更新波段点信息（只有在非替换模式下才更新secondLast）
         if(!isConsecutiveLowReplacement)
           {
            secondLastSwingIndex = lastSwingIndex;
            secondLastSwingPrice = lastSwingPrice;
           }
         
         lastSwingType = -1;
         lastSwingIndex = checkIndex;
         lastSwingPrice = curLow;
         
         // 更新最后的低点信息
         lastLowIndex = checkIndex;
         lastLowPrice = curLow;
         newSwingPointFound = true;
         
         // 更新前期低点跟踪
         UpdatePrevLowPoints(curLow);
         
         // 只有在非替换模式下才添加到扩展低点跟踪数组
         if(!isConsecutiveLowReplacement)
           {
            UpdateAllLowPoints(curLow, checkIndex);
           }
         
         // 添加到摆动点历史记录并进行趋势分析
         if(!isConsecutiveLowReplacement)
           {
            AddToSwingHistory(curLow, checkIndex, time[checkIndex], false);
            if(ShowTrendAnalysis)
              {
               AnalyzeTrend();
               UpdateTrendLabel();
              }
           }
        }
     }

   // 打印性能信息
   datetime endTime = TimeCurrent();
   if(processedBars > 0)
     {
      Print("处理了 ", processedBars, " 根K线，用时 ", (endTime - startTime), " 秒");
     }

   // 在所有波段点计算完成后，统一绘制趋势线和斐波那契回调
   // 修复：确保实时更新显示
   if(newSwingPointFound && lastSwingIndex >= 0 && secondLastSwingIndex >= 0)
     {
      DrawTradingTools(lastSwingIndex, lastSwingPrice, secondLastSwingIndex, secondLastSwingPrice, (lastSwingType == 1), time);
     }
   
   // 强制刷新图表以确保新的箭头和线条能够显示
   if(newSwingPointFound || processedBars > 0)
     {
      ChartRedraw(0);
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
      
      // 初始化前期高低点数据
      InitializePrevHighLowFromFound(foundCount, foundTypes, foundPrices);
     }
   else
     {
      Print("在指定范围内未找到波段点，将从头开始计算");
     }
  }

//+------------------------------------------------------------------+
//| 从找到的波段点初始化前期高低点                                       |
//+------------------------------------------------------------------+
void InitializePrevHighLowFromFound(int foundCount, int &foundTypes[], double &foundPrices[])
  {
   // 重置计数器
   highPointsFound = 0;
   lowPointsFound = 0;
   ArrayInitialize(recentHighs, 0);
   ArrayInitialize(recentLows, 0);
   
   // 重置扩展跟踪
   totalHighsFound = 0;
   totalLowsFound = 0;
   ArrayInitialize(allRecentHighs, 0);
   ArrayInitialize(allRecentLows, 0);
   ArrayInitialize(allRecentHighsIndices, -1);
   ArrayInitialize(allRecentLowsIndices, -1);
   
   // 从最近找到的波段点中提取高点和低点
   for(int i = 0; i < foundCount; i++)
     {
      if(foundTypes[i] == 1) // 高点
        {
         if(highPointsFound < 2)
           {
            recentHighs[highPointsFound] = foundPrices[i];
            highPointsFound++;
           }
        }
      else if(foundTypes[i] == -1) // 低点
        {
         if(lowPointsFound < 2)
           {
            recentLows[lowPointsFound] = foundPrices[i];
            lowPointsFound++;
           }
        }
     }
   
   // 计算前期高低点
   if(highPointsFound >= 1)
     {
      prevHighPrice = recentHighs[0];
      if(highPointsFound == 2)
        {
         prevHighPrice = MathMax(recentHighs[0], recentHighs[1]);
        }
     }
   
   if(lowPointsFound >= 1)
     {
      prevLowPrice = recentLows[0];
      if(lowPointsFound == 2)
        {
         prevLowPrice = MathMin(recentLows[0], recentLows[1]);
        }
     }
   
   Print("初始化前期高低点 - 高点数:", highPointsFound, ", 前期高点:", prevHighPrice, 
         ", 低点数:", lowPointsFound, ", 前期低点:", prevLowPrice);
  }

//+------------------------------------------------------------------+
//| 绘制交易工具函数                                                    |
//+------------------------------------------------------------------+
void DrawTradingTools(int currentIndex, double currentPrice, int lastIndex, double lastPrice, bool isHigh, const datetime &time[])
  {
   // 使用传入的time数组获取时间
   datetime currentTime = time[currentIndex];
   datetime lastTime = time[lastIndex];
   
   // 绘制趋势线 - 只绘制最新的趋势线
   if(ShowTrendLines)
     {
      DrawTrendLine(currentIndex, currentPrice, lastIndex, lastPrice, currentTime, lastTime);
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
   
   // 绘制前期高低点水平线
   if(ShowPrevHighLow)
     {
      DrawPrevHighLowLines();
     }
   
   // 绘制高点顶部和低点底部射线
   if(ShowHighTopLine || ShowLowBottomLine)
     {
      DrawTopBottomLines(time);
     }
  }

//+------------------------------------------------------------------+
//| 绘制趋势线                                                         |
//+------------------------------------------------------------------+
void DrawTrendLine(int currentIndex, double currentPrice, int lastIndex, double lastPrice, datetime currentTime, datetime lastTime)
  {
   // 使用波段点索引作为唯一标识符
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
           
         Print("绘制趋势线：从[", lastIndex, "] ", lastPrice, " 到[", currentIndex, "] ", currentPrice);
        }
     }
   else
     {
      // 如果趋势线已存在，更新其坐标（防止数据更新导致的位置偏移）
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, lastTime);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, lastPrice);
      ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, currentTime);
      ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, currentPrice);
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
   
   // 如果斐波那契对象已经是最新的，不需要重绘
   if(lastCreatedFibLevel == fibName && ObjectFind(0, fibName) >= 0)
     {
      return;
     }
   
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
         
         // 批量设置斐波那契水平
         double levels[5] = {0.0, 0.5, 1, 1.5, 2.0};
         string texts[5] = {"0", "0.5", "1", "1.5", "2"};
         
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
   else
     {
      // 如果斐波那契对象已存在，更新其坐标
      ObjectSetInteger(0, fibName, OBJPROP_TIME, 0, highTime);
      ObjectSetDouble(0, fibName, OBJPROP_PRICE, 0, lastHighPrice);
      ObjectSetInteger(0, fibName, OBJPROP_TIME, 1, lowTime);
      ObjectSetDouble(0, fibName, OBJPROP_PRICE, 1, lastLowPrice);
      
      // 删除上一个斐波那契回调
      if(lastCreatedFibLevel != "" && lastCreatedFibLevel != fibName)
        {
         ObjectDelete(0, lastCreatedFibLevel);
        }
      
      lastCreatedFibLevel = fibName;
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
      if(StringFind(objName, trendLineName) >= 0 || 
         StringFind(objName, fibLevelName) >= 0 ||
         StringFind(objName, prevHighLineName) >= 0 ||
         StringFind(objName, prevLowLineName) >= 0 ||
         StringFind(objName, highTopLineName) >= 0 ||
         StringFind(objName, lowBottomLineName) >= 0 ||
         StringFind(objName, relationLabelPrefix) >= 0 ||
         StringFind(objName, trendLabelName) >= 0)
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
//| 更新前期高点跟踪                                                    |
//+------------------------------------------------------------------+
void UpdatePrevHighPoints(double newHigh)
  {
   if(highPointsFound == 0)
     {
      // 第一个高点
      recentHighs[0] = newHigh;
      highPointsFound = 1;
      prevHighPrice = newHigh;
     }
   else if(highPointsFound == 1)
     {
      // 第二个高点
      recentHighs[1] = newHigh;
      highPointsFound = 2;
      // 取两个高点中较高的作为前期高点
      prevHighPrice = MathMax(recentHighs[0], recentHighs[1]);
     }
   else
     {
      // 已有两个高点，移位并添加新高点
      recentHighs[0] = recentHighs[1];
      recentHighs[1] = newHigh;
      // 取两个高点中较高的作为前期高点
      prevHighPrice = MathMax(recentHighs[0], recentHighs[1]);
     }
   
   Print("更新前期高点：新高点=", newHigh, ", 前期高点=", prevHighPrice);
  }

//+------------------------------------------------------------------+
//| 更新前期低点跟踪                                                    |
//+------------------------------------------------------------------+
void UpdatePrevLowPoints(double newLow)
  {
   if(lowPointsFound == 0)
     {
      // 第一个低点
      recentLows[0] = newLow;
      lowPointsFound = 1;
      prevLowPrice = newLow;
     }
   else if(lowPointsFound == 1)
     {
      // 第二个低点
      recentLows[1] = newLow;
      lowPointsFound = 2;
      // 取两个低点中较低的作为前期低点
      prevLowPrice = MathMin(recentLows[0], recentLows[1]);
     }
   else
     {
      // 已有两个低点，移位并添加新低点
      recentLows[0] = recentLows[1];
      recentLows[1] = newLow;
      // 取两个低点中较低的作为前期低点
      prevLowPrice = MathMin(recentLows[0], recentLows[1]);
     }
   
   Print("更新前期低点：新低点=", newLow, ", 前期低点=", prevLowPrice);
  }

//+------------------------------------------------------------------+
//| 绘制前期高低点水平线                                                 |
//+------------------------------------------------------------------+
void DrawPrevHighLowLines()
  {
   // 绘制前期高点线
   if(prevHighPrice > 0)
     {
      if(ObjectFind(0, prevHighLineName) < 0)
        {
         // 创建水平线（射线）
         if(ObjectCreate(0, prevHighLineName, OBJ_HLINE, 0, 0, prevHighPrice))
           {
            ObjectSetInteger(0, prevHighLineName, OBJPROP_COLOR, PrevHighColor);
            ObjectSetInteger(0, prevHighLineName, OBJPROP_WIDTH, PrevLineWidth);
            ObjectSetInteger(0, prevHighLineName, OBJPROP_STYLE, PrevLineStyle);
            ObjectSetInteger(0, prevHighLineName, OBJPROP_BACK, false);
            ObjectSetString(0, prevHighLineName, OBJPROP_TEXT, "Prev High: " + DoubleToString(prevHighPrice, _Digits));
           }
        }
      else
        {
         // 更新现有水平线的价格
         ObjectSetDouble(0, prevHighLineName, OBJPROP_PRICE, 0, prevHighPrice);
         ObjectSetString(0, prevHighLineName, OBJPROP_TEXT, "Prev High: " + DoubleToString(prevHighPrice, _Digits));
        }
     }
   
   // 绘制前期低点线
   if(prevLowPrice > 0)
     {
      if(ObjectFind(0, prevLowLineName) < 0)
        {
         // 创建水平线（射线）
         if(ObjectCreate(0, prevLowLineName, OBJ_HLINE, 0, 0, prevLowPrice))
           {
            ObjectSetInteger(0, prevLowLineName, OBJPROP_COLOR, PrevLowColor);
            ObjectSetInteger(0, prevLowLineName, OBJPROP_WIDTH, PrevLineWidth);
            ObjectSetInteger(0, prevLowLineName, OBJPROP_STYLE, PrevLineStyle);
            ObjectSetInteger(0, prevLowLineName, OBJPROP_BACK, false);
            ObjectSetString(0, prevLowLineName, OBJPROP_TEXT, "Prev Low: " + DoubleToString(prevLowPrice, _Digits));
           }
        }
      else
        {
         // 更新现有水平线的价格
         ObjectSetDouble(0, prevLowLineName, OBJPROP_PRICE, 0, prevLowPrice);
         ObjectSetString(0, prevLowLineName, OBJPROP_TEXT, "Prev Low: " + DoubleToString(prevLowPrice, _Digits));
        }
     }
  }

//+------------------------------------------------------------------+
//| 更新所有高点跟踪                                                    |
//+------------------------------------------------------------------+
void UpdateAllHighPoints(double newHigh, int newIndex)
  {
   // 移位数组，添加新高点
   for(int i = 3; i > 0; i--)
     {
      allRecentHighs[i] = allRecentHighs[i-1];
      allRecentHighsIndices[i] = allRecentHighsIndices[i-1];
     }
   
   // 添加新高点到最前面
   allRecentHighs[0] = newHigh;
   allRecentHighsIndices[0] = newIndex;
   
   if(totalHighsFound < 4)
      totalHighsFound++;
   
   // 清理数组中无效的高点
   CleanupInvalidHighPoints();
   
   Print("更新有箭头的高点：新高点[", newIndex, "]=", newHigh, ", 总高点数=", totalHighsFound);
   
   // 打印当前所有高点数组状态
   string debugStr = "高点数组状态: ";
   for(int i = 0; i < totalHighsFound; i++)
     {
      debugStr += StringFormat("[%d]:%.5f@%d ", i, allRecentHighs[i], allRecentHighsIndices[i]);
     }
   Print(debugStr);
  }

//+------------------------------------------------------------------+
//| 更新所有低点跟踪                                                    |
//+------------------------------------------------------------------+
void UpdateAllLowPoints(double newLow, int newIndex)
  {
   // 移位数组，添加新低点
   for(int i = 3; i > 0; i--)
     {
      allRecentLows[i] = allRecentLows[i-1];
      allRecentLowsIndices[i] = allRecentLowsIndices[i-1];
     }
   
   // 添加新低点到最前面
   allRecentLows[0] = newLow;
   allRecentLowsIndices[0] = newIndex;
   
   if(totalLowsFound < 4)
      totalLowsFound++;
   
   // 清理数组中无效的低点
   CleanupInvalidLowPoints();
   
   Print("更新有箭头的低点：新低点[", newIndex, "]=", newLow, ", 总低点数=", totalLowsFound);
   
   // 打印当前所有低点数组状态
   string debugStr = "低点数组状态: ";
   for(int i = 0; i < totalLowsFound; i++)
     {
      debugStr += StringFormat("[%d]:%.5f@%d ", i, allRecentLows[i], allRecentLowsIndices[i]);
     }
   Print(debugStr);
  }

//+------------------------------------------------------------------+
//| 绘制高点顶部和低点底部射线                                           |
//+------------------------------------------------------------------+
void DrawTopBottomLines(const datetime &time[])
  {
   // 绘制高点顶部射线（连接倒数第2和倒数第3个有箭头的高点）
   if(ShowHighTopLine && totalHighsFound >= 3)
     {
      // 查找倒数第2个和倒数第3个真正有箭头的高点，确保索引不重复
      int validHighIndices[2];
      double validHighPrices[2];
      int validCount = 0;
      
      // 从数组中查找有效且不重复的高点（跳过索引0，因为那是最新的）
      for(int i = 1; i < totalHighsFound && validCount < 2; i++)
        {
         int index = allRecentHighsIndices[i];
         if(index >= 0 && SwingHighBuffer[index] != EMPTY_VALUE)
           {
            // 检查是否与已找到的索引重复
            bool isDuplicate = false;
            for(int j = 0; j < validCount; j++)
              {
               if(validHighIndices[j] == index)
                 {
                  isDuplicate = true;
                  break;
                 }
              }
            
            // 只添加不重复的索引
            if(!isDuplicate)
              {
               validHighIndices[validCount] = index;
               validHighPrices[validCount] = allRecentHighs[i];
               validCount++;
              }
           }
        }
      
      // 确保找到了至少2个有效且不重复的高点
      if(validCount >= 2)
        {
         int index2 = validHighIndices[0]; // 倒数第2个有效高点
         int index3 = validHighIndices[1]; // 倒数第3个有效高点
         double price2 = validHighPrices[0];
         double price3 = validHighPrices[1];
         
         datetime time2 = time[index2];
         datetime time3 = time[index3];
         
         // 确保索引不同（双重检查）
         if(index2 != index3)
           {
            if(ObjectFind(0, highTopLineName) < 0)
              {
               // 创建射线，从较早的点到较晚的点
               if(ObjectCreate(0, highTopLineName, OBJ_TREND, 0, time3, price3, time2, price2))
                 {
                  ObjectSetInteger(0, highTopLineName, OBJPROP_COLOR, HighTopColor);
                  ObjectSetInteger(0, highTopLineName, OBJPROP_WIDTH, TopBottomLineWidth);
                  ObjectSetInteger(0, highTopLineName, OBJPROP_STYLE, TopBottomLineStyle);
                  ObjectSetInteger(0, highTopLineName, OBJPROP_RAY_RIGHT, true);
                  ObjectSetInteger(0, highTopLineName, OBJPROP_RAY_LEFT, false);
                  ObjectSetInteger(0, highTopLineName, OBJPROP_BACK, false);
                  
                  Print("创建高点顶部射线：从[", index3, "] ", price3, " 到[", index2, "] ", price2, " (找到", validCount, "个有效高点)");
                 }
              }
            else
              {
               // 更新现有射线
               ObjectSetInteger(0, highTopLineName, OBJPROP_TIME, 0, time3);
               ObjectSetDouble(0, highTopLineName, OBJPROP_PRICE, 0, price3);
               ObjectSetInteger(0, highTopLineName, OBJPROP_TIME, 1, time2);
               ObjectSetDouble(0, highTopLineName, OBJPROP_PRICE, 1, price2);
              }
           }
         else
           {
            Print("错误：倒数第2个和倒数第3个高点索引相同 [", index2, "], 跳过射线绘制");
           }
        }
      else
        {
         Print("高点顶部射线跳过：只找到", validCount, "个有效且不重复的高点，需要至少2个");
        }
     }
   
   // 绘制低点底部射线（连接倒数第3个和倒数第2个有箭头的低点）
   if(ShowLowBottomLine && totalLowsFound >= 3)
     {
      // 查找倒数第3个和倒数第2个真正有箭头的低点，确保索引不重复
      int validLowIndices[3];
      double validLowPrices[3];
      int validCount = 0;
      
      // 从数组中查找所有有效且不重复的低点
      for(int i = 0; i < totalLowsFound && validCount < 3; i++)
        {
         int index = allRecentLowsIndices[i];
         if(index >= 0 && SwingLowBuffer[index] != EMPTY_VALUE)
           {
            // 检查是否与已找到的索引重复
            bool isDuplicate = false;
            for(int j = 0; j < validCount; j++)
              {
               if(validLowIndices[j] == index)
                 {
                  isDuplicate = true;
                  break;
                 }
              }
            
            // 只添加不重复的索引
            if(!isDuplicate)
              {
               validLowIndices[validCount] = index;
               validLowPrices[validCount] = allRecentLows[i];
               validCount++;
              }
           }
        }
      
      // 确保找到了至少3个有效且不重复的低点，连接倒数第3个和倒数第2个
      if(validCount >= 3)
        {
         int index2 = validLowIndices[1]; // 倒数第2个有效低点
         int index3 = validLowIndices[2]; // 倒数第3个有效低点
         double price2 = validLowPrices[1];
         double price3 = validLowPrices[2];
         
         datetime time2 = time[index2];
         datetime time3 = time[index3];
         
         // 打印调试信息显示连接的具体低点
         Print("低点底部射线连接：倒数第3个低点[", index3, "] ", price3, " -> 倒数第2个低点[", index2, "] ", price2);
         Print("当前低点数组状态 - 总数:", totalLowsFound, ", 有效不重复数:", validCount);
         Print("最新3个有效低点: [", validLowIndices[0], "]", validLowPrices[0], ", [", validLowIndices[1], "]", validLowPrices[1], ", [", validLowIndices[2], "]", validLowPrices[2]);
         
         // 确保索引不同（双重检查）
         if(index2 != index3)
           {
            if(ObjectFind(0, lowBottomLineName) < 0)
              {
               // 创建射线，从较早的点到较晚的点
               if(ObjectCreate(0, lowBottomLineName, OBJ_TREND, 0, time3, price3, time2, price2))
                 {
                  ObjectSetInteger(0, lowBottomLineName, OBJPROP_COLOR, LowBottomColor);
                  ObjectSetInteger(0, lowBottomLineName, OBJPROP_WIDTH, TopBottomLineWidth);
                  ObjectSetInteger(0, lowBottomLineName, OBJPROP_STYLE, TopBottomLineStyle);
                  ObjectSetInteger(0, lowBottomLineName, OBJPROP_RAY_RIGHT, true);
                  ObjectSetInteger(0, lowBottomLineName, OBJPROP_RAY_LEFT, false);
                  ObjectSetInteger(0, lowBottomLineName, OBJPROP_BACK, false);
                  
                  Print("成功创建低点底部射线：从倒数第3个[", index3, "] ", price3, " 到倒数第2个[", index2, "] ", price2);
                 }
              }
            else
              {
               // 更新现有射线
               ObjectSetInteger(0, lowBottomLineName, OBJPROP_TIME, 0, time3);
               ObjectSetDouble(0, lowBottomLineName, OBJPROP_PRICE, 0, price3);
               ObjectSetInteger(0, lowBottomLineName, OBJPROP_TIME, 1, time2);
               ObjectSetDouble(0, lowBottomLineName, OBJPROP_PRICE, 1, price2);
               
               Print("成功更新低点底部射线：从倒数第3个[", index3, "] ", price3, " 到倒数第2个[", index2, "] ", price2);
              }
           }
         else
           {
            Print("错误：倒数第2个和倒数第3个低点索引相同 [", index2, "], 跳过射线绘制");
           }
        }
      else
        {
         Print("低点底部射线跳过：只找到", validCount, "个有效且不重复的低点，需要至少3个");
        }
     }
  }

//+------------------------------------------------------------------+
//| 清理无效的高点                                                      |
//+------------------------------------------------------------------+
void CleanupInvalidHighPoints()
  {
   // 压缩数组，移除无效的高点
   int validCount = 0;
   double tempHighs[4];
   int tempIndices[4];
   
   for(int i = 0; i < totalHighsFound; i++)
     {
      int index = allRecentHighsIndices[i];
      if(index >= 0 && SwingHighBuffer[index] != EMPTY_VALUE)
        {
         tempHighs[validCount] = allRecentHighs[i];
         tempIndices[validCount] = allRecentHighsIndices[i];
         validCount++;
        }
     }
   
   // 如果清理后数量有变化，更新数组
   if(validCount != totalHighsFound)
     {
      Print("清理高点数组：移除了", (totalHighsFound - validCount), "个无效点，剩余", validCount, "个有效点");
      
      // 更新数组
      for(int i = 0; i < 4; i++)
        {
         if(i < validCount)
           {
            allRecentHighs[i] = tempHighs[i];
            allRecentHighsIndices[i] = tempIndices[i];
           }
         else
           {
            allRecentHighs[i] = 0;
            allRecentHighsIndices[i] = -1;
           }
        }
      
      totalHighsFound = validCount;
     }
  }

//+------------------------------------------------------------------+
//| 清理无效的低点                                                      |
//+------------------------------------------------------------------+
void CleanupInvalidLowPoints()
  {
   // 压缩数组，移除无效的低点
   int validCount = 0;
   double tempLows[4];
   int tempIndices[4];
   
   for(int i = 0; i < totalLowsFound; i++)
     {
      int index = allRecentLowsIndices[i];
      if(index >= 0 && SwingLowBuffer[index] != EMPTY_VALUE)
        {
         tempLows[validCount] = allRecentLows[i];
         tempIndices[validCount] = allRecentLowsIndices[i];
         validCount++;
        }
     }
   
   // 如果清理后数量有变化，更新数组
   if(validCount != totalLowsFound)
     {
      Print("清理低点数组：移除了", (totalLowsFound - validCount), "个无效点，剩余", validCount, "个有效点");
      
      // 更新数组
      for(int i = 0; i < 4; i++)
        {
         if(i < validCount)
           {
            allRecentLows[i] = tempLows[i];
            allRecentLowsIndices[i] = tempIndices[i];
           }
         else
           {
            allRecentLows[i] = 0;
            allRecentLowsIndices[i] = -1;
           }
        }
      
      totalLowsFound = validCount;
     }
  }

//+------------------------------------------------------------------+
//| 处理连续高点去重                                                    |
//| 功能: 当检测到连续的高点时，比较它们的优劣并保留更优的那个              |
//| 参数: currentHigh - 当前检测到的高点价格                            |
//|       currentIndex - 当前高点的K线索引                             |
//| 返回: true = 当前高点更优，已替换上一个； false = 上一个更优，忽略当前  |
//| 改进: 1. 逻辑更清晰，单独处理去重                                   |
//|       2. 详细的日志输出，便于调试                                   |
//|       3. 安全的数组更新，避免索引错误                               |
//+------------------------------------------------------------------+
bool ProcessConsecutiveHighPoints(double currentHigh, int currentIndex)
  {
   // 检查当前高点是否比上一个高点更高
   if(currentHigh > lastSwingPrice)
     {
      // 当前高点更高，替换上一个高点
      Print("连续高点去重：当前高点", currentHigh, "[", currentIndex, "] 高于上一个", lastSwingPrice, "[", lastSwingIndex, "]，替换上一个");
      
      // 清除上一个高点的箭头
      if(lastSwingIndex >= 0)
        {
         SwingHighBuffer[lastSwingIndex] = EMPTY_VALUE;
         
         // 删除上一个高点的关系标签
         if(ShowSwingRelationLabels)
           {
            DeleteRelationLabelsAtIndex(lastSwingIndex);
           }
        }
      
      // 更新扩展高点跟踪数组中的最新点（如果存在）
      if(totalHighsFound > 0)
        {
         // 替换数组中最新的高点数据
         allRecentHighs[0] = currentHigh;
         allRecentHighsIndices[0] = currentIndex;
         Print("更新扩展高点数组：替换最新高点为", currentHigh, "@", currentIndex);
        }
      
      return true; // 当前高点更优
     }
   else
     {
      // 上一个高点更高，保留上一个，忽略当前
      Print("连续高点去重：当前高点", currentHigh, "[", currentIndex, "] 低于上一个", lastSwingPrice, "[", lastSwingIndex, "]，忽略当前");
      return false; // 上一个更优
     }
  }

//+------------------------------------------------------------------+
//| 处理连续低点去重                                                    |
//| 功能: 当检测到连续的低点时，比较它们的优劣并保留更优的那个              |
//| 参数: currentLow - 当前检测到的低点价格                             |
//|       currentIndex - 当前低点的K线索引                             |
//| 返回: true = 当前低点更优，已替换上一个； false = 上一个更优，忽略当前  |
//| 改进: 1. 逻辑更清晰，单独处理去重                                   |
//|       2. 详细的日志输出，便于调试                                   |
//|       3. 安全的数组更新，避免索引错误                               |
//+------------------------------------------------------------------+
bool ProcessConsecutiveLowPoints(double currentLow, int currentIndex)
  {
   // 检查当前低点是否比上一个低点更低
   if(currentLow < lastSwingPrice)
     {
      // 当前低点更低，替换上一个低点
      Print("连续低点去重：当前低点", currentLow, "[", currentIndex, "] 低于上一个", lastSwingPrice, "[", lastSwingIndex, "]，替换上一个");
      
      // 清除上一个低点的箭头
      if(lastSwingIndex >= 0)
        {
         SwingLowBuffer[lastSwingIndex] = EMPTY_VALUE;
         
         // 删除上一个低点的关系标签
         if(ShowSwingRelationLabels)
           {
            DeleteRelationLabelsAtIndex(lastSwingIndex);
           }
        }
      
      // 更新扩展低点跟踪数组中的最新点（如果存在）
      if(totalLowsFound > 0)
        {
         // 替换数组中最新的低点数据
         allRecentLows[0] = currentLow;
         allRecentLowsIndices[0] = currentIndex;
         Print("更新扩展低点数组：替换最新低点为", currentLow, "@", currentIndex);
        }
      
      return true; // 当前低点更优
     }
   else
     {
      // 上一个低点更低，保留上一个，忽略当前
      Print("连续低点去重：当前低点", currentLow, "[", currentIndex, "] 高于上一个", lastSwingPrice, "[", lastSwingIndex, "]，忽略当前");
      return false; // 上一个更优
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 初始化摆动点数据结构                                                 |
//+------------------------------------------------------------------+
void InitializeSwingPointData(SwingPointData &point)
  {
   point.price = 0;
   point.index = -1;
   point.time = 0;
   point.relation = "";
  }

//+------------------------------------------------------------------+
//| 计算高点关系                                                        |
//+------------------------------------------------------------------+
string CalculateHighRelation(double currentHigh, int currentIndex, const datetime &time[])
  {
   string relation = "";
   
   // 如果没有前一个高点，这是第一个高点
   if(lastHighPoint.index == -1)
     {
      // 保存当前高点为前一个高点，为下次比较做准备
      secondLastHighPoint = lastHighPoint;
      lastHighPoint.price = currentHigh;
      lastHighPoint.index = currentIndex;
      lastHighPoint.time = time[currentIndex];
      lastHighPoint.relation = "First High";
      return ""; // 第一个高点不显示关系标签
     }
   
   // 比较当前高点与前一个高点
   if(currentHigh > lastHighPoint.price)
     {
      relation = "HH"; // Higher High
     }
   else
     {
      relation = "LH"; // Lower High
     }
   
   // 创建关系标签
   CreateSwingRelationLabel(currentHigh, currentIndex, time[currentIndex], relation, true);
   
   // 更新高点历史
   secondLastHighPoint = lastHighPoint;
   lastHighPoint.price = currentHigh;
   lastHighPoint.index = currentIndex;
   lastHighPoint.time = time[currentIndex];
   lastHighPoint.relation = relation;
   
   Print("高点关系计算：当前高点 ", currentHigh, " [", currentIndex, "] 相对于前一个高点 ", 
         secondLastHighPoint.price, " [", secondLastHighPoint.index, "] 的关系是：", relation);
   
   return relation;
  }

//+------------------------------------------------------------------+
//| 计算低点关系                                                        |
//+------------------------------------------------------------------+
string CalculateLowRelation(double currentLow, int currentIndex, const datetime &time[])
  {
   string relation = "";
   
   // 如果没有前一个低点，这是第一个低点
   if(lastLowPoint.index == -1)
     {
      // 保存当前低点为前一个低点，为下次比较做准备
      secondLastLowPoint = lastLowPoint;
      lastLowPoint.price = currentLow;
      lastLowPoint.index = currentIndex;
      lastLowPoint.time = time[currentIndex];
      lastLowPoint.relation = "First Low";
      return ""; // 第一个低点不显示关系标签
     }
   
   // 比较当前低点与前一个低点
   if(currentLow > lastLowPoint.price)
     {
      relation = "HL"; // Higher Low
     }
   else
     {
      relation = "LL"; // Lower Low
     }
   
   // 创建关系标签
   CreateSwingRelationLabel(currentLow, currentIndex, time[currentIndex], relation, false);
   
   // 更新低点历史
   secondLastLowPoint = lastLowPoint;
   lastLowPoint.price = currentLow;
   lastLowPoint.index = currentIndex;
   lastLowPoint.time = time[currentIndex];
   lastLowPoint.relation = relation;
   
   Print("低点关系计算：当前低点 ", currentLow, " [", currentIndex, "] 相对于前一个低点 ", 
         secondLastLowPoint.price, " [", secondLastLowPoint.index, "] 的关系是：", relation);
   
   return relation;
  }

//+------------------------------------------------------------------+
//| 创建摆动点关系标签                                                   |
//+------------------------------------------------------------------+
void CreateSwingRelationLabel(double price, int barIndex, datetime barTime, string relation, bool isHigh)
  {
   // 生成唯一的标签名称
   string labelName = relationLabelPrefix + IntegerToString(labelCounter) + "_" + relation + "_" + IntegerToString(barIndex);
   labelCounter++;
   
   // 计算标签位置（在箭头上方或下方）
   double labelPrice;
   ENUM_ANCHOR_POINT anchor;
   color labelColor;
   
   if(isHigh)
     {
      labelPrice = price + effectiveArrowGap * 2; // 在高点箭头上方
      anchor = ANCHOR_LOWER;
      
      if(relation == "HH")
         labelColor = HigherHighColor;
      else
         labelColor = LowerHighColor;
     }
   else
     {
      labelPrice = price - effectiveArrowGap * 2; // 在低点箭头下方
      anchor = ANCHOR_UPPER;
      
      if(relation == "HL")
         labelColor = HigherLowColor;
      else
         labelColor = LowerLowColor;
     }
   
   // 创建文本标签
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, barTime, labelPrice))
     {
      ObjectSetString(0, labelName, OBJPROP_TEXT, relation);
      ObjectSetString(0, labelName, OBJPROP_FONT, LabelFont);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, LabelFontSize);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
      
      Print("创建关系标签：", relation, " 在 [", barIndex, "] ", price, " 时间：", TimeToString(barTime));
     }
   else
     {
      Print("创建关系标签失败：", relation, " 在 [", barIndex, "] ", price);
     }
  }

//+------------------------------------------------------------------+
//| 删除特定索引处的关系标签                                              |
//+------------------------------------------------------------------+
void DeleteRelationLabelsAtIndex(int barIndex)
  {
   int totalObjects = ObjectsTotal(0);
   string labelsToDelete[];
   int deleteCount = 0;
   
   // 查找包含特定索引的关系标签
   for(int i = 0; i < totalObjects; i++)
     {
      string objName = ObjectName(0, i);
      if(StringFind(objName, relationLabelPrefix) >= 0 && 
         StringFind(objName, "_" + IntegerToString(barIndex)) >= 0)
        {
         ArrayResize(labelsToDelete, deleteCount + 1);
         labelsToDelete[deleteCount] = objName;
         deleteCount++;
        }
     }
   
   // 删除找到的标签
   for(int i = 0; i < deleteCount; i++)
     {
      ObjectDelete(0, labelsToDelete[i]);
      Print("删除关系标签：", labelsToDelete[i]);
     }
  }

//+------------------------------------------------------------------+
//| 添加摆动点到历史记录                                                 |
//+------------------------------------------------------------------+
void AddToSwingHistory(double price, int index, datetime time, bool isHigh)
  {
   // 向前移位数组
   for(int i = 7; i > 0; i--)
     {
      swingHistory[i] = swingHistory[i-1];
     }
   
   // 添加新的摆动点到首位
   swingHistory[0].price = price;
   swingHistory[0].index = index;
   swingHistory[0].time = time;
   swingHistory[0].relation = isHigh ? "H" : "L";
   
   if(swingHistoryCount < 8)
      swingHistoryCount++;
   
   Print("添加摆动点到历史：", (isHigh ? "高点" : "低点"), " 价格=", price, " 索引=", index, " 总数=", swingHistoryCount);
  }

//+------------------------------------------------------------------+
//| 分析趋势                                                            |
//+------------------------------------------------------------------+
void AnalyzeTrend()
  {
   if(swingHistoryCount < TrendAnalysisPeriod)
     {
      currentTrend = TREND_RANGE;
      Print("趋势分析：摆动点数量不足，当前=", swingHistoryCount, ", 需要=", TrendAnalysisPeriod);
      return;
     }
   
   // 分离高点和低点，保持时间顺序（最新的在前）
   double highs[];
   double lows[];
   int highCount = 0;
   int lowCount = 0;
   
   for(int i = 0; i < TrendAnalysisPeriod && i < swingHistoryCount; i++)
     {
      if(swingHistory[i].relation == "H")
        {
         ArrayResize(highs, highCount + 1);
         highs[highCount] = swingHistory[i].price;
         highCount++;
        }
      else if(swingHistory[i].relation == "L")
        {
         ArrayResize(lows, lowCount + 1);
         lows[lowCount] = swingHistory[i].price;
         lowCount++;
        }
     }
   
   // 至少需要2个高点和2个低点来分析趋势
   if(highCount < 2 || lowCount < 2)
     {
      currentTrend = TREND_RANGE;
      Print("趋势分析：高低点数量不足 - 高点=", highCount, ", 低点=", lowCount, " (各需要>=2)");
      return;
     }
   
   // 分析高点趋势（最新的在数组开头，索引0是最新的）
   bool highsRising = true;
   bool highsFalling = true;
   for(int i = 0; i < highCount - 1; i++)
     {
      // 比较：更新的价格 vs 更老的价格
      if(highs[i] <= highs[i+1]) highsRising = false;  // 如果新高点不高于老高点，则不是上升
      if(highs[i] >= highs[i+1]) highsFalling = false; // 如果新高点不低于老高点，则不是下降
     }
   
   // 分析低点趋势
   bool lowsRising = true;
   bool lowsFalling = true;
   for(int i = 0; i < lowCount - 1; i++)
     {
      // 比较：更新的价格 vs 更老的价格
      if(lows[i] <= lows[i+1]) lowsRising = false;   // 如果新低点不高于老低点，则不是上升
      if(lows[i] >= lows[i+1]) lowsFalling = false;  // 如果新低点不低于老低点，则不是下降
     }
   
   // 判断趋势
   if(highsRising && lowsRising)
     {
      currentTrend = TREND_UP;
      Print("趋势分析：上升趋势 (HH + HL) - 高点上升:", highsRising, ", 低点上升:", lowsRising);
     }
   else if(highsFalling && lowsFalling)
     {
      currentTrend = TREND_DOWN;
      Print("趋势分析：下降趋势 (LH + LL) - 高点下降:", highsFalling, ", 低点下降:", lowsFalling);
     }
   else
     {
      currentTrend = TREND_RANGE;
      Print("趋势分析：交易区间 (混合模式) - 高点上升:", highsRising, ", 高点下降:", highsFalling, ", 低点上升:", lowsRising, ", 低点下降:", lowsFalling);
     }
   
   // 打印详细调试信息
   string debugStr = "最近" + IntegerToString(highCount) + "个高点序列(新->老): ";
   for(int i = 0; i < highCount; i++)
     {
      debugStr += DoubleToString(highs[i], 5);
      if(i < highCount - 1) debugStr += " -> ";
     }
   Print(debugStr);
   
   debugStr = "最近" + IntegerToString(lowCount) + "个低点序列(新->老): ";
   for(int i = 0; i < lowCount; i++)
     {
      debugStr += DoubleToString(lows[i], 5);
      if(i < lowCount - 1) debugStr += " -> ";
     }
   Print(debugStr);
  }

//+------------------------------------------------------------------+
//| 更新趋势标签                                                        |
//+------------------------------------------------------------------+
void UpdateTrendLabel()
  {
   // 删除旧的趋势标签
   ObjectDelete(0, trendLabelName);
   
   // 确定标签文本和颜色
   string trendText = "";
   color trendColor = clrWhite;
   
   switch(currentTrend)
     {
      case TREND_UP:
         trendText = "趋势：上升 ↗";
         trendColor = UpTrendColor;
         break;
      case TREND_DOWN:
         trendText = "趋势：下降 ↘";
         trendColor = DownTrendColor;
         break;
      case TREND_RANGE:
         trendText = "趋势：区间 ↔";
         trendColor = RangeColor;
         break;
     }
   
   // 添加摆动点数量信息
   trendText += " (" + IntegerToString(swingHistoryCount) + "点)";
   
   // 获取图表的右上角位置
   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   // 计算标签位置（右上角，留出边距）
   int labelX = (int)(chartWidth - 200); // 距离右边缘200像素，为更长的文本留出空间
   int labelY = 30; // 距离顶部30像素
   
   // 确保标签位置不会超出屏幕边界
   if(labelX < 10) labelX = 10;
   
   // 创建标签
   if(ObjectCreate(0, trendLabelName, OBJ_LABEL, 0, 0, 0))
     {
      ObjectSetString(0, trendLabelName, OBJPROP_TEXT, trendText);
      ObjectSetString(0, trendLabelName, OBJPROP_FONT, LabelFont);
      ObjectSetInteger(0, trendLabelName, OBJPROP_FONTSIZE, TrendLabelFontSize);
      ObjectSetInteger(0, trendLabelName, OBJPROP_COLOR, trendColor);
      ObjectSetInteger(0, trendLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, trendLabelName, OBJPROP_XDISTANCE, labelX);
      ObjectSetInteger(0, trendLabelName, OBJPROP_YDISTANCE, labelY);
      ObjectSetInteger(0, trendLabelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, trendLabelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, trendLabelName, OBJPROP_HIDDEN, true);
      
      Print("更新趋势标签：", trendText, " 位置：(", labelX, ",", labelY, ")");
     }
   else
     {
      Print("创建趋势标签失败：", trendText);
     }
  }
