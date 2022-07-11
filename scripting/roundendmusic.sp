#include <sourcemod>
#include <sdktools>
#include <colors>
#include <clientprefs>
#include <cstrike>
bool soundLib;
#include <abnersound>

#pragma newdecls required
#pragma semicolon 1
#define PLUGIN_VERSION "1.1"

char sSectionName[255];
char sSongName[255];
char sAuthor[255];

//Cvars
ConVar g_hGlobalSoundPath;
ConVar g_hPlayType;
ConVar g_hStop;
ConVar g_PlayPrint;
ConVar g_ClientSettings; 
ConVar g_SoundVolume;
ConVar g_playToTheEnd;

//Handles
Handle g_ResPlayCookie;
Handle g_ResVolumeCookie;

//Sounds Arrays
ArrayList globalSoundsArray;
StringMap soundNames;
StringMap soundAuthors;

public Plugin myinfo =
{
	name 			= "CLNissen Round End Sounds (AbNeR inspired)",
	author 			= "CLNissen",
	description 	= "Spil sange ved round end",
	version 		=  PLUGIN_VERSION,
	url 			= "hjemezez.dk"
}

public void OnPluginStart()
{  
	//Cvars
	CreateConVar("abner_res_version", PLUGIN_VERSION, "Plugin version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	
	g_hGlobalSoundPath         = CreateConVar("res_global_sound_path", "csgo/addons/sourcemod/data/music", "Path of sounds played when any team wins the round");
		
	g_hPlayType                = CreateConVar("res_play_type", "1", "1 - Random, 2 - Play in queue");
	g_hStop                    = CreateConVar("res_stop_map_music", "1", "Stop map musics");	
	
	g_PlayPrint                = CreateConVar("res_print_to_chat_mp3_name", "1", "Print mp3 name in scoreboard position");
	g_ClientSettings	       = CreateConVar("res_client_preferences", "1", "Enable/Disable client preferences");

	g_SoundVolume 			   = CreateConVar("res_default_volume", "0.75", "Default sound volume.");
	g_playToTheEnd 			   = CreateConVar("res_play_to_the_end", "0", "Play sounds to the end.");
	
	//ClientPrefs
	g_ResPlayCookie = RegClientCookie("AbNeR Round End Sounds", "", CookieAccess_Private);
	g_ResVolumeCookie = RegClientCookie("abner_res_volume", "Round end sound volume", CookieAccess_Private);

	SetCookieMenuItem(SoundCookieHandler, 0, "AbNeR Round End Sounds");
	
	LoadTranslations("common.phrases");
	LoadTranslations("abner_res.phrases");
	AutoExecConfig(true);

	/* CMDS */
	RegAdminCmd("res_refresh", CommandLoad, ADMFLAG_ROOT);
	RegConsoleCmd("res", abnermenu);
		
	
	/* EVENTS */
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	
	soundLib = (GetFeatureStatus(FeatureType_Native, "GetSoundLengthFloat") == FeatureStatus_Available);

	globalSoundsArray = new ArrayList(512);
	soundNames = new StringMap();
	soundAuthors = new StringMap();

	OnMapStart();
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarInt(g_hStop) == 1)
	{
		MapSounds();
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	bool random = GetConVarInt(g_hPlayType) == 1;

	char szSound[128];

	bool Success = false;
	Success = GetSound(globalSoundsArray, g_hGlobalSoundPath, random, szSound, sizeof(szSound));
	
	if(Success) {
		PlayMusicAll(szSound);
		
		if(GetConVarInt(g_hStop) == 1)
		{
			StopMapMusic();
		}

		if(GetConVarBool(g_playToTheEnd) && soundLib) {
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

void PlayMusicAll(char[] szSound)
{
	char soundKey[100];
	char buffer[20][255];
	char soundName[512];
	char soundAuthor[512];

	int numberRetrieved = ExplodeString(szSound, "/", buffer, sizeof(buffer), sizeof(buffer[]), false);
	if (numberRetrieved > 0)
	{
		Format(soundKey, sizeof(soundKey), buffer[numberRetrieved - 1]);
	}
	soundNames.GetString(soundKey, soundName, sizeof(soundName));
	soundAuthors.GetString(soundKey, soundAuthor, sizeof(soundAuthor));

	char displayString[1024];
	Format(displayString, sizeof(displayString), "<b><span class='fontSize-xxl' color='#00FFEC'>%s</span> <span class='fontSize-xxl' color='#FFFFFF'> - </span> <span class='fontSize-xxl' color='#FA0000'>%s</span></b>", soundName, soundAuthor);

	Event res_event_message = CreateEvent("cs_win_panel_round");
	res_event_message.SetString("funfact_token", displayString);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && (GetConVarInt(g_ClientSettings) == 0 || GetIntCookie(i, g_ResPlayCookie) == 0))
		{
			if(GetConVarInt(g_PlayPrint) == 1)
			{
				res_event_message.FireToClient(i);
			}
			float selectedVolume = GetClientVolume(i);
			PlaySoundClient(i, szSound, selectedVolume);
		}
	}

	res_event_message.Cancel();
}

public void SoundCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	abnermenu(client, 0);
} 

public void OnClientPutInServer(int client)
{
	if(GetConVarInt(g_ClientSettings) == 1)
	{
		CreateTimer(3.0, msg, client);
	}
}

public Action msg(Handle timer, any client)
{
	if(IsValidClient(client))
	{
		CPrintToChat(client, "{default}{green}[HjemEZEZ Music] {default}%t", "JoinMsg");
	}

	return Plugin_Handled;
}

public Action abnermenu(int client, int args)
{
	if(GetConVarInt(g_ClientSettings) != 1)
	{
		return Plugin_Handled;
	}
	
	int cookievalue = GetIntCookie(client, g_ResPlayCookie);
	Handle g_CookieMenu = CreateMenu(AbNeRMenuHandler);
	SetMenuTitle(g_CookieMenu, "Round End Sounds by AbNeR_CSS (Edited by CLNissen)");
	char Item[128];
	if(cookievalue == 0)
	{
		Format(Item, sizeof(Item), "%t %t", "RES_ON", "Selected"); 
		AddMenuItem(g_CookieMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t", "RES_OFF"); 
		AddMenuItem(g_CookieMenu, "OFF", Item);
	}
	else
	{
		Format(Item, sizeof(Item), "%t", "RES_ON");
		AddMenuItem(g_CookieMenu, "ON", Item);
		Format(Item, sizeof(Item), "%t %t", "RES_OFF", "Selected"); 
		AddMenuItem(g_CookieMenu, "OFF", Item);
	}

	Format(Item, sizeof(Item), "%t", "VOLUME");
	AddMenuItem(g_CookieMenu, "volume", Item);


	SetMenuExitBackButton(g_CookieMenu, true);
	SetMenuExitButton(g_CookieMenu, true);
	DisplayMenu(g_CookieMenu, client, 30);
	return Plugin_Continue;
}

public int AbNeRMenuHandler(Handle menu, MenuAction action, int client, int param2)
{
	Handle g_CookieMenu = CreateMenu(AbNeRMenuHandler);
	if (action == MenuAction_DrawItem)
	{
		return ITEMDRAW_DEFAULT;
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		ShowCookieMenu(client);
	}
	else if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				SetClientCookie(client, g_ResPlayCookie, "0");
				abnermenu(client, 0);
			}
			case 1:
			{
				SetClientCookie(client, g_ResPlayCookie, "1");
				abnermenu(client, 0);
			}
			case 2: 
			{
				VolumeMenu(client);
			}
		}
		CloseHandle(g_CookieMenu);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void VolumeMenu(int client) {
	float volumeArray[] = { 1.0, 0.75, 0.50, 0.25, 0.10 };
	float selectedVolume = GetClientVolume(client);

	Menu volumeMenu = new Menu(VolumeMenuHandler);
	volumeMenu.SetTitle("%t", "Sound Menu Title");
	volumeMenu.ExitBackButton = true;

	for(int i = 0; i < sizeof(volumeArray); i++)
	{
		char strInfo[10];
		Format(strInfo, sizeof(strInfo), "%0.2f", volumeArray[i]);

		char display[20], selected[5];
		if(volumeArray[i] == selectedVolume)
			Format(selected, sizeof(selected), "%t", "Selected");

		Format(display, sizeof(display), "%s %s", strInfo, selected);

		volumeMenu.AddItem(strInfo, display);
	}

	volumeMenu.Display(client, MENU_TIME_FOREVER);
}

int VolumeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select){
		char sInfo[10];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		SetClientCookie(client, g_ResVolumeCookie, sInfo);
		VolumeMenu(client);
	}
	else if(param2 == MenuCancel_ExitBack)
	{
		abnermenu(client, 0);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}


public void OnMapStart()
{
	RefreshSounds(0);
}

void RefreshSounds(int client)
{
	char globalSoundPath[PLATFORM_MAX_PATH];
	
	GetConVarString(g_hGlobalSoundPath, globalSoundPath, sizeof(globalSoundPath));
	ReplyToCommand(client, "[HjemEZEZ Music] SOUNDS: %d sounds loaded from \"sound/%s\"", LoadSounds(globalSoundsArray, g_hGlobalSoundPath), globalSoundPath);
	
	ParseSongNameKvFile();
}


public void ParseSongNameKvFile()
{
	soundNames.Clear();
	soundAuthors.Clear();

	char sPath[PLATFORM_MAX_PATH];
	Format(sPath, sizeof(sPath), "configs/abner_res.txt");
	BuildPath(Path_SM, sPath, sizeof(sPath), sPath);

	if (!FileExists(sPath))
		return;

	KeyValues hKeyValues = CreateKeyValues("Abner Res");
	if (!hKeyValues.ImportFromFile(sPath)) {
		SetFailState("Cant find file", sPath);
		return;
	}

	if(hKeyValues.GotoFirstSubKey())
	{
		do
		{
		
			hKeyValues.GetSectionName(sSectionName, sizeof(sSectionName));
			hKeyValues.GetString("songname", sSongName, sizeof(sSongName));
			hKeyValues.GetString("author", sAuthor, sizeof(sAuthor));
		
			
			soundNames.SetString(sSectionName, sSongName);
			soundAuthors.SetString(sSectionName, sAuthor);
		}
		while(hKeyValues.GotoNextKey(false));
	}
	hKeyValues.Close();
}

public Action CommandLoad(int client, int args)
{   
	RefreshSounds(client);
	return Plugin_Handled;
}

/* Helpers */
stock bool IsValidClient(int client)
{
	if(client <= 0 ) return false;
	if(client > MaxClients) return false;
	if(!IsClientConnected(client)) return false;
	if(IsFakeClient(client)) return false;
	return IsClientInGame(client);
}

float GetClientVolume(int client){
	float defaultVolume = GetConVarFloat(g_SoundVolume);

	char sCookieValue[11];
	GetClientCookie(client, g_ResVolumeCookie, sCookieValue, sizeof(sCookieValue));

	if(!GetConVarBool(g_ClientSettings) || StrEqual(sCookieValue, "") || StrEqual(sCookieValue, "0"))
		Format(sCookieValue , sizeof(sCookieValue), "%0.2f", defaultVolume);

	return StringToFloat(sCookieValue);
}

int GetIntCookie(int client, Handle handle)
{
	char sCookieValue[11];
	GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
	return StringToInt(sCookieValue);
}