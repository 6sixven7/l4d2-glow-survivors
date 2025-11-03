// =========================================================
// L4D2 RGB Glow Plugin v3 - Model & Outline (GlowMenu Logic)
// =========================================================

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colors>

#define GLOW_BRIGHTNESS 180

enum GlowType
{
    TYPE_NONE = 0,
    TYPE_MODEL,
    TYPE_OUTLINE
};

// 定义菜单模式
enum GlowMode
{
    MODE_STATIC = 0,
    MODE_DYNAMIC,
    MODE_RAINBOW
};

// 每个玩家的数据结构
enum struct PlayerGlow
{
    GlowType type;
    GlowMode mode;
    Handle timer;
    float phase;
}

PlayerGlow g_Player[MAXPLAYERS + 1];

// 颜色定义表
char staticColors[][] = {
    "绿色", "蓝色", "蓝紫色", "水蓝色", "橘黄色",
    "红色", "灰色", "黄色", "绿黄色", "栗色",
    "蓝绿色", "粉红色", "紫色", "白色", "金黄色"
};

// RGB 颜色数组 (R, G, B)
int staticRGB[][] = {
    {0, 180, 0},      // 绿色
    {0, 0, 180},      // 蓝色
    {120, 0, 180},    // 蓝紫色
    {0, 180, 180},    // 水蓝色
    {255, 128, 0},    // 橘黄色
    {180, 0, 0},      // 红色
    {100, 100, 100},  // 灰色
    {180, 180, 0},    // 黄色
    {128, 255, 0},    // 绿黄色
    {128, 0, 0},      // 栗色
    {0, 180, 120},    // 蓝绿色
    {255, 105, 180},  // 粉红色
    {180, 0, 180},    // 紫色
    {180, 180, 180},  // 白色
    {255, 215, 0}     // 金黄色
};

public Plugin myinfo =
{
    name = "L4D2 RGB Glow (Model & Outline, Merged)",
    author = "i forgor",
    description = "RGB Glow for survivors", 
    version = "3.0", 
    url = "https://github.com/6sixven7/"
};

// =========================================================
// inspired by https://www.kitasoda.com & https://forums.alliedmods.net/showthread.php?t=332956
// =========================================================
public void OnPluginStart()
{
    RegConsoleCmd("sm_rgb", Command_RgbMenu, "打开颜色选择菜单");
    PrintToServer("[RGBGlow] 插件已加载。使用 !rgb 打开菜单。");
}

public Action Command_RgbMenu(int client, int args)
{
    if (!IsClientInGame(client) || IsFakeClient(client))
        return Plugin_Handled;
    ShowTypeMenu(client);
    return Plugin_Handled;
}

// =========================================================
// 菜单处理
// =========================================================

// 显示发光类型菜单 
void ShowTypeMenu(int client)
{
    Menu menu = new Menu(MenuHandler_TypeSelect);
    menu.SetTitle("选择发光类型");

    menu.AddItem("MODEL", "模型发光 (Model Glow)");
    menu.AddItem("OUTLINE", "轮廓发光 (Outline Glow)");
    menu.AddItem("NONE", "关闭发光 (Turn Off)");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TypeSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "MODEL"))
        {
            g_Player[client].type = TYPE_MODEL;
            ShowColorMenu(client); // 显示颜色选择菜单
        }
        else if (StrEqual(info, "OUTLINE"))
        {
            g_Player[client].type = TYPE_OUTLINE;
            ShowColorMenu(client); // 显示颜色选择菜单
        }
        else if (StrEqual(info, "NONE"))
        {
            StopGlow(client);
            g_Player[client].type = TYPE_NONE;
            PrintToChat(client, "[RGBGlow] 你已关闭发光效果。");
        }
    }
    return 0;
}

// 显示颜色选择菜单
void ShowColorMenu(int client)
{
    Menu menu = new Menu(MenuHandler_ColorSelect);

    // 根据发光类型设置菜单标题
    if (g_Player[client].type == TYPE_MODEL)
    {
        menu.SetTitle("选择模型发光颜色");
    }
    else if (g_Player[client].type == TYPE_OUTLINE)
    {
        menu.SetTitle("选择轮廓发光颜色");
    }
    else // fallback, should not happen if logic is correct
    {
        menu.SetTitle("选择人物发光颜色");
    }


    char buffer[8];
    for (int i = 0; i < sizeof(staticColors); i++)
    {
        IntToString(i, buffer, sizeof(buffer));
        menu.AddItem(buffer, staticColors[i]);
    }

    menu.AddItem("DYNAMIC", "动态彩色（管理员专用）");
    menu.AddItem("RAINBOW", "彩虹环流（管理员专用）");

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

// 菜单处理
public int MenuHandler_ColorSelect(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
    else if (action == MenuAction_Select)
    {
        int client = param1;
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        // 检查是否已选择发光类型
        if (g_Player[client].type == TYPE_NONE)
        {
            PrintToChat(client, "[RGBGlow] 请先选择发光类型 (Model/Outline)。");
            return 0;
        }

        if (StrEqual(info, "DYNAMIC"))
        {
            if (!CheckCommandAccess(client, "rgb_admin", ADMFLAG_GENERIC))
            {
                PrintToChat(client, "[RGBGlow] 此功能仅限管理员使用。");
                return 0;
            }
            StartDynamicGlow(client);
        }
        else if (StrEqual(info, "RAINBOW"))
        {
            if (!CheckCommandAccess(client, "rgb_admin", ADMFLAG_GENERIC))
            {
                PrintToChat(client, "[RGBGlow] 此功能仅限管理员使用。");
                return 0;
            }
            StartRainbowGlow(client);
        }
        else
        {
            int index = StringToInt(info);
            // 调用新的设置静态颜色函数，它会根据 g_Player[client].type 来设置发光效果
            SetStaticGlow(client, staticRGB[index][0], staticRGB[index][1], staticRGB[index][2]);
            PrintToChat(client, "[RGBGlow] 你已选择 %s 发光。", staticColors[index]);
        }
    }
    return 0;
}

// =========================================================
// 辅助函数
// =========================================================

// 将 RGB 颜色分量转换为 BGR 整数
int RgbToBgrInt(int r, int g, int b)
{
    // BGR 格式: B + (G * 256) + (R * 65536)
    // 注意: SourceMod 属性经常使用 BGR 格式
    return b + (g * 256) + (r * 65536);
}


void SetEntityOutlineGlow(int entity, int r, int g, int b, int a)
{
    // 清除可能残留的 RENDER_NORMAL 或 RENDER_GLOW 效果
    SetEntityRenderMode(entity, RENDER_NORMAL);
    SetEntityRenderColor(entity, 255, 255, 255, 255); 
    
    // BGR 整数颜色值
    int glowColor = RgbToBgrInt(r, g, b);

    // 设置 Glow 属性 (m_iGlowType=2 为轮廓线发光)
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", glowColor);
    SetEntProp(entity, Prop_Send, "m_iGlowType", 2);  // 类型 2: 轮廓发光
    SetEntProp(entity, Prop_Send, "m_nGlowRange", 99999);
    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
}

// 设置实体模型发光 
void SetEntityModelGlow(int entity, int r, int g, int b, int a)
{
    // 清除 Glow 属性，防止干扰 RENDER_GLOW
    ClearGlowProperties(entity);
    
    // 设置 RENDER_GLOW 效果
    SetEntityRenderMode(entity, RENDER_GLOW);
    SetEntityRenderColor(entity, r, g, b, a);
}

// 清除 Glow 属性
void ClearGlowProperties(int entity)
{
    SetEntProp(entity, Prop_Send, "m_glowColorOverride", 0);
    SetEntProp(entity, Prop_Send, "m_iGlowType", 0);
    SetEntProp(entity, Prop_Send, "m_nGlowRange", 0);
    SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", 0);
}

// 设置静态颜色
void SetStaticGlow(int client, int r, int g, int b)
{
    StopGlow(client);
    if (g_Player[client].type == TYPE_MODEL)
    {
        SetEntityModelGlow(client, r, g, b, GLOW_BRIGHTNESS);
    }
    else if (g_Player[client].type == TYPE_OUTLINE)
    {
        SetEntityOutlineGlow(client, r, g, b, GLOW_BRIGHTNESS);
    }
    
    g_Player[client].mode = MODE_STATIC;
}

// 启动动态彩色（柔和彩）
void StartDynamicGlow(int client)
{
    StopGlow(client);
    g_Player[client].mode = MODE_DYNAMIC;
    g_Player[client].phase = 0.0;
    g_Player[client].timer = CreateTimer(0.15, Timer_Dynamic, client, TIMER_REPEAT);
    PrintToChat(client, "[RGBGlow] 你已启用动态彩色发光。");
}

public Action Timer_Dynamic(Handle timer, any client)
{
    if (!IsClientInGame(client))
        return Plugin_Stop;

    // 检查是否选择了发光类型
    if (g_Player[client].type == TYPE_NONE)
        return Plugin_Stop;

    g_Player[client].phase += 10.0;
    float rad = DegToRad(g_Player[client].phase);

    int r = RoundToNearest(127.0 * (Sine(rad) + 1.0));
    int g = RoundToNearest(127.0 * (Sine(rad + 2.09) + 1.0));
    int b = RoundToNearest(127.0 * (Sine(rad + 4.18) + 1.0));

    // 根据发光类型设置发光效果
    if (g_Player[client].type == TYPE_MODEL)
    {
        SetEntityModelGlow(client, r, g, b, GLOW_BRIGHTNESS);
    }
    else if (g_Player[client].type == TYPE_OUTLINE)
    {
        SetEntityOutlineGlow(client, r, g, b, GLOW_BRIGHTNESS);
    }

    return Plugin_Continue;
}

// 启动彩虹环流模式
void StartRainbowGlow(int client)
{
    StopGlow(client);
    g_Player[client].mode = MODE_RAINBOW;
    g_Player[client].phase = 0.0;
    g_Player[client].timer = CreateTimer(0.05, Timer_Rainbow, client, TIMER_REPEAT);
    PrintToChat(client, "[RGBGlow] 你已启用彩虹环流发光。");
}

public Action Timer_Rainbow(Handle timer, any client)
{
    if (!IsClientInGame(client))
        return Plugin_Stop;

    // 检查是否选择了发光类型
    if (g_Player[client].type == TYPE_NONE)
        return Plugin_Stop;

    g_Player[client].phase += 20.0;
    float rad = DegToRad(g_Player[client].phase);

    int r = RoundToNearest(127.0 * (Sine(rad) + 1.0));
    int g = RoundToNearest(127.0 * (Sine(rad + 1.57) + 1.0));
    int b = RoundToNearest(127.0 * (Sine(rad + 3.14) + 1.0));

    // 根据发光类型设置发光效果
    if (g_Player[client].type == TYPE_MODEL)
    {
        SetEntityModelGlow(client, r, g, b, GLOW_BRIGHTNESS);
    }
    else if (g_Player[client].type == TYPE_OUTLINE)
    {
        SetEntityOutlineGlow(client, r, g, b, GLOW_BRIGHTNESS);
    }

    return Plugin_Continue;
}

// 停止发光效果
void StopGlow(int client)
{
    if (g_Player[client].timer != null)
    {
        delete g_Player[client].timer;
        g_Player[client].timer = null;
    }
    g_Player[client].mode = MODE_STATIC;

    // 停止发光时，重置渲染模式和效果
    SetEntityRenderMode(client, RENDER_NORMAL);
    SetEntityRenderColor(client, 255, 255, 255, 255);
    
    // 清除 Glow 属性
    ClearGlowProperties(client);
}