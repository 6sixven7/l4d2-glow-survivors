#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <keyvalues>

#define PLUGIN_VERSION "5.0"
#define CONFIG_FILE "configs/rgbglow.kv"
#define GLOW_BRIGHTNESS 180

// 发光类型枚举
enum GlowType
{
    TYPE_NONE = 0,
    TYPE_MODEL,    // 模型发光
    TYPE_OUTLINE,  // 轮廓发光
    TYPE_SKIN      // 皮肤发光
}

// 动态效果模式
enum GlowMode  
{
    MODE_STATIC = 0,
    MODE_DYNAMIC,  // 柔彩
    MODE_RAINBOW   // 环流彩
}

// 玩家数据结构
enum struct PlayerData
{
    GlowType type;
    GlowMode mode;
    int colorIndex;
    Handle timer;
    float phase;
}

PlayerData g_Player[MAXPLAYERS + 1];

// 15种静态颜色
#define COLOR_COUNT 15
char g_ColorNames[COLOR_COUNT][] = {
    "绿色", "蓝色", "蓝紫色", "水蓝色", "橘黄色",
    "红色", "灰色", "黄色", "绿黄色", "栗色",
    "蓝绿色", "粉红色", "紫色", "白色", "金黄色"
};

int g_ColorValues[COLOR_COUNT][3] = {
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
    name = "L4D2 RGB Glow v5",
    author = "6sixven7",
    description = "RGB发光插件 v5",
    version = PLUGIN_VERSION,
    url = "https://github.com/6sixven7/"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_rgb", Command_RgbMenu, "打开RGB发光菜单");
    
    // 确保配置文件夹存在
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs");
    if(!DirExists(path))
    {
        CreateDirectory(path, 511);
    }
    
    // 加载所有玩家数据
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            LoadPlayerData(i);
        }
    }
}

public void OnClientConnected(int client)
{
    // 初始化玩家数据
    g_Player[client].type = TYPE_NONE;
    g_Player[client].mode = MODE_STATIC;
    g_Player[client].colorIndex = 0;
    g_Player[client].timer = null;
    g_Player[client].phase = 0.0;
}

public void OnClientPutInServer(int client)
{
    if(!IsFakeClient(client))
    {
        LoadPlayerData(client);
    }
}

public void OnClientDisconnect(int client)
{
    if(!IsFakeClient(client))
    {
        SavePlayerData(client);
    }
    StopEffects(client);
}

public Action Command_RgbMenu(int client, int args)
{
    if(!IsValidClient(client))
        return Plugin_Handled;
        
    ShowMainMenu(client);
    return Plugin_Handled;
}

void ShowMainMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Main);
    menu.SetTitle("RGB发光菜单");
    
    menu.AddItem("model", "模型发光");
    menu.AddItem("outline", "轮廓发光");
    menu.AddItem("skin", "皮肤发光");
    
    // 使用ADMFLAG_GENERIC检查普通管理员权限
    if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
    {
        menu.AddItem("reset", "重置配置文件 [管理员]");
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

void ShowColorMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Color);
    menu.SetTitle("选择颜色效果");
    
    char info[8];
    for(int i = 0; i < COLOR_COUNT; i++)
    {
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, g_ColorNames[i]);
    }
    
    if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
    {
        menu.AddItem("dynamic", "柔和彩色 [管理员]");
        menu.AddItem("rainbow", "环流彩色 [管理员]");
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

// 继续下一部分...需要我继续吗？

public int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            if(StrEqual(info, "model"))
            {
                g_Player[client].type = TYPE_MODEL;
                ShowColorMenu(client);
            }
            else if(StrEqual(info, "outline"))
            {
                g_Player[client].type = TYPE_OUTLINE;
                ShowColorMenu(client);
            }
            else if(StrEqual(info, "skin"))
            {
                g_Player[client].type = TYPE_SKIN;
                ShowColorMenu(client);
            }
            else if(StrEqual(info, "reset"))
            {
                ShowResetConfirmMenu(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public int MenuHandler_Color(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            if(StrEqual(info, "dynamic"))
            {
                if(!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
                {
                    CPrintToChat(client, "{green}[RGB]{default} 只有管理员才能使用此效果!");
                    ShowColorMenu(client);
                    return 0;
                }
                StartDynamicEffect(client);
            }
            else if(StrEqual(info, "rainbow"))
            {
                if(!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
                {
                    CPrintToChat(client, "{green}[RGB]{default} 只有管理员才能使用此效果!");
                    ShowColorMenu(client);
                    return 0;
                }
                StartRainbowEffect(client);
            }
            else
            {
                int colorIndex = StringToInt(info);
                SetStaticColor(client, colorIndex);
            }
            
            SavePlayerData(client);
            CPrintToChat(client, "{green}[RGB]{default} 颜色设置已保存。");
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
            {
                ShowMainMenu(param1);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

void ShowResetConfirmMenu(int client)
{
    Menu menu = new Menu(MenuHandler_ResetConfirm);
    menu.SetTitle("确定要重置配置文件吗?\n这将删除所有玩家的设置!");
    
    menu.AddItem("yes", "是,重置配置");
    menu.AddItem("no", "否,返回主菜单");
    
    menu.ExitButton = false;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ResetConfirm(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            int client = param1;
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            
            if(StrEqual(info, "yes"))
            {
                ResetConfig();
                CPrintToChat(client, "{green}[RGB]{default} 配置文件已重置!");
            }
            ShowMainMenu(client);
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

void SetStaticColor(int client, int colorIndex)
{
    StopEffects(client);
    g_Player[client].colorIndex = colorIndex;
    g_Player[client].mode = MODE_STATIC;
    
    int r = g_ColorValues[colorIndex][0];
    int g = g_ColorValues[colorIndex][1];
    int b = g_ColorValues[colorIndex][2];
    
    switch(g_Player[client].type)
    {
        case TYPE_MODEL:
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, r, g, b, GLOW_BRIGHTNESS);
        }
        case TYPE_OUTLINE:
        {
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", RgbToBgrInt(r, g, b));
        }
        case TYPE_SKIN:
        {
            SetEntityRenderColor(client, r, g, b, 255);
        }
    }
}

// 动态效果计时器函数和KV文件操作部分需要继续吗？

// 动态彩色效果
void StartDynamicEffect(int client)
{
    StopEffects(client);
    g_Player[client].mode = MODE_DYNAMIC;
    g_Player[client].phase = 0.0;
    g_Player[client].timer = CreateTimer(0.1, Timer_DynamicEffect, client, TIMER_REPEAT);
}

public Action Timer_DynamicEffect(Handle timer, any client)
{
    if(!IsValidClient(client))
    {
        g_Player[client].timer = null;
        return Plugin_Stop;
    }

    g_Player[client].phase += 10.0;
    float rad = DegToRad(g_Player[client].phase);
    
    int r = RoundToNearest(127.0 * (Sine(rad) + 1.0));
    int g = RoundToNearest(127.0 * (Sine(rad + 2.09) + 1.0));
    int b = RoundToNearest(127.0 * (Sine(rad + 4.18) + 1.0));

    switch(g_Player[client].type)
    {
        case TYPE_MODEL:
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, r, g, b, GLOW_BRIGHTNESS);
        }
        case TYPE_OUTLINE:
        {
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", RgbToBgrInt(r, g, b));
        }
        case TYPE_SKIN:
        {
            SetEntityRenderColor(client, r, g, b, 255);
        }
    }
    
    return Plugin_Continue;
}

// 彩虹环流效果
void StartRainbowEffect(int client)
{
    StopEffects(client);
    g_Player[client].mode = MODE_RAINBOW;
    g_Player[client].phase = 0.0;
    g_Player[client].timer = CreateTimer(0.05, Timer_RainbowEffect, client, TIMER_REPEAT);
}

public Action Timer_RainbowEffect(Handle timer, any client)
{
    if(!IsValidClient(client))
    {
        g_Player[client].timer = null;
        return Plugin_Stop;
    }

    g_Player[client].phase += 20.0;
    float rad = DegToRad(g_Player[client].phase);
    
    int r = RoundToNearest(127.0 * (Sine(rad) + 1.0));
    int g = RoundToNearest(127.0 * (Sine(rad + 1.57) + 1.0));
    int b = RoundToNearest(127.0 * (Sine(rad + 3.14) + 1.0));

    switch(g_Player[client].type)
    {
        case TYPE_MODEL:
        {
            SetEntityRenderMode(client, RENDER_GLOW);
            SetEntityRenderColor(client, r, g, b, GLOW_BRIGHTNESS);
        }
        case TYPE_OUTLINE:
        {
            SetEntProp(client, Prop_Send, "m_iGlowType", 3);
            SetEntProp(client, Prop_Send, "m_glowColorOverride", RgbToBgrInt(r, g, b));
        }
        case TYPE_SKIN:
        {
            SetEntityRenderColor(client, r, g, b, 255);
        }
    }
    
    return Plugin_Continue;
}

// KeyValues配置文件操作
void SavePlayerData(int client)
{
    char steamid[64];
    if(!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
        return;
        
    KeyValues kv = new KeyValues("RGBGlow");
    kv.ImportFromFile(CONFIG_FILE);
    
    kv.JumpToKey(steamid, true);
    kv.SetNum("type", view_as<int>(g_Player[client].type));
    kv.SetNum("mode", view_as<int>(g_Player[client].mode));
    kv.SetNum("colorIndex", g_Player[client].colorIndex);
    kv.Rewind();
    
    kv.ExportToFile(CONFIG_FILE);
    delete kv;
}

void LoadPlayerData(int client)
{
    char steamid[64];
    if(!GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid)))
        return;
        
    KeyValues kv = new KeyValues("RGBGlow");
    if(!kv.ImportFromFile(CONFIG_FILE))
    {
        delete kv;
        return;
    }
    
    if(kv.JumpToKey(steamid))
    {
        g_Player[client].type = view_as<GlowType>(kv.GetNum("type"));
        g_Player[client].mode = view_as<GlowMode>(kv.GetNum("mode")); 
        g_Player[client].colorIndex = kv.GetNum("colorIndex");
        
        // 应用保存的效果
        if(g_Player[client].mode == MODE_STATIC)
        {
            SetStaticColor(client, g_Player[client].colorIndex);
        }
        else if(g_Player[client].mode == MODE_DYNAMIC)
        {
            StartDynamicEffect(client);
        }
        else if(g_Player[client].mode == MODE_RAINBOW)
        {
            StartRainbowEffect(client);
        }
    }
    
    delete kv;
}

void ResetConfig()
{
    // 删除配置文件
    DeleteFile(CONFIG_FILE);
    
    // 重置所有在线玩家的效果
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
        {
            StopEffects(i);
            g_Player[i].type = TYPE_NONE;
            g_Player[i].mode = MODE_STATIC;
            g_Player[i].colorIndex = 0;
        }
    }
    
    // 创建新的空配置文件
    KeyValues kv = new KeyValues("RGBGlow");
    kv.ExportToFile(CONFIG_FILE);
    delete kv;
}

void StopEffects(int client)
{
    // 停止计时器
    if(g_Player[client].timer != null)
    {
        KillTimer(g_Player[client].timer);
        g_Player[client].timer = null;
    }
    
    // 重置渲染
    SetEntityRenderMode(client, RENDER_NORMAL);
    SetEntityRenderColor(client, 255, 255, 255, 255);
    
    // 清除发光效果
    SetEntProp(client, Prop_Send, "m_iGlowType", 0);
    SetEntProp(client, Prop_Send, "m_glowColorOverride", 0);
}

// 辅助函数
bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

int RgbToBgrInt(int r, int g, int b)
{
    return (b + (g << 8) + (r << 16));
}