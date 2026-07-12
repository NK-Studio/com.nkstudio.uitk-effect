using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace NKStudio.UITKEffects.Editor
{
    internal static class UITKEffectsLocalization
    {
        private const string LocalizationPath =
            "Packages/com.nkstudio.uitk-effects/Editor/UI/Localization.json";

        private static Dictionary<string, LocalizationEntry> _entries;

        private static bool IsKorean => Application.systemLanguage == SystemLanguage.Korean;

        internal static string Get(string key, params object[] args)
        {
            EnsureLoaded();

            if (!_entries.TryGetValue(key, out var entry))
            {
                Debug.LogWarning($"UITK Effects localization key '{key}' was not found.");
                return key;
            }

            var text = IsKorean ? entry.kr : entry.en;
            return args.Length > 0 ? string.Format(text, args) : text;
        }

        private static void EnsureLoaded()
        {
            if (_entries != null)
                return;

            _entries = new Dictionary<string, LocalizationEntry>();

            var json = AssetDatabase.LoadAssetAtPath<TextAsset>(LocalizationPath);
            if (json == null)
            {
                Debug.LogError($"UITK Effects localization file was not found at '{LocalizationPath}'.");
                return;
            }

            var table = JsonUtility.FromJson<LocalizationTable>(json.text);
            if (table?.entries == null)
                return;

            foreach (var entry in table.entries)
                _entries[entry.key] = entry;
        }

        [Serializable]
        private sealed class LocalizationEntry
        {
            public string key;
            public string en;
            public string kr;
        }

        [Serializable]
        private sealed class LocalizationTable
        {
            public LocalizationEntry[] entries;
        }
    }
}
