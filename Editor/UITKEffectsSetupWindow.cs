using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEditor.PackageManager.UI;
using UnityEngine;
using UnityEngine.UIElements;

namespace NKStudio.UITKEffects.Editor
{
    internal sealed class UITKEffectsSetupWindow : EditorWindow
    {
        internal static string ShowAtStartupKey =>
            $"NKStudio.UITKEffects.ShowSetupAtStartup.{Hash128.Compute(Application.dataPath)}";

        private const string LayoutPath =
            "Packages/com.nkstudio.uitk-effects/Editor/UI/UITKEffectsSetupWindow.uxml";

        private const string FilterSourceFolder =
            "Packages/com.nkstudio.uitk-effects/Scripts/Runtime/Filters";

        private const string MaterialSourceFolder =
            "Packages/com.nkstudio.uitk-effects/Art/Materials";

        private const string PackageName = "com.nkstudio.uitk-effects";
        private const string Unity63SampleName = "Filter Sample (Unity 6.3)";
        private const string Unity65SampleName = "Filter Sample (Unity 6.5+)";

        private const string InstallRoot = "Assets/UITK Effects";
        private const string FilterTargetFolder = "Assets/UITK Effects/Filter Definitions";
        private const string MaterialTargetFolder = "Assets/UITK Effects/Materials";

        private static readonly InstallAssetInfo[] InstallAssets =
        {
            new InstallAssetInfo(FilterSourceFolder, FilterTargetFolder, "DropShadowFilter.asset", "drop-shadow-status", "drop-shadow-name", "Drop Shadow"),
            new InstallAssetInfo(FilterSourceFolder, FilterTargetFolder, "InnerShadowFilter.asset", "inner-shadow-status", "inner-shadow-name", "Inner Shadow"),
            new InstallAssetInfo(FilterSourceFolder, FilterTargetFolder, "OuterGlowFilter.asset", "outer-glow-status", "outer-glow-name", "Outer Glow"),
            new InstallAssetInfo(FilterSourceFolder, FilterTargetFolder, "OutlineFilter.asset", "outline-status", "outline-name", "Outline"),
            new InstallAssetInfo(MaterialSourceFolder, MaterialTargetFolder, "Gradient.mat", "gradient-status", "gradient-name", "Gradient Material")
        };

        private readonly Dictionary<string, Label> _statusLabels = new Dictionary<string, Label>();

        private Button _installButton;
        private Button _openFolderButton;
        private Button _importSampleButton;
        private Button _showSampleButton;
        private Label _resultMessage;

        [MenuItem("Tools/UITK Effects/Setup Window")]
        internal static void ShowSetupWindow()
        {
            var window = GetWindow<UITKEffectsSetupWindow>(true, "UITK Effects Setup", true);
            window.minSize = new Vector2(520f, 680f);
            window.maxSize = new Vector2(720f, 920f);
            window.Show();
        }

        internal static bool AreAllAssetsInstalled()
        {
            foreach (var installAsset in InstallAssets)
            {
                if (AssetDatabase.LoadMainAssetAtPath(installAsset.TargetPath) == null)
                    return false;
            }

            return true;
        }

        public void CreateGUI()
        {
            var layout = AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(LayoutPath);
            if (layout == null)
            {
                Debug.LogError($"UITK Effects setup layout was not found at '{LayoutPath}'.");
                return;
            }

            layout.CloneTree(rootVisualElement);

            _installButton = rootVisualElement.Q<Button>("install-button");
            _openFolderButton = rootVisualElement.Q<Button>("open-folder-button");
            _importSampleButton = rootVisualElement.Q<Button>("import-sample-button");
            _showSampleButton = rootVisualElement.Q<Button>("show-sample-button");
            _resultMessage = rootVisualElement.Q<Label>("result-message");

            foreach (var installAsset in InstallAssets)
            {
                _statusLabels[installAsset.StatusElementName] =
                    rootVisualElement.Q<Label>(installAsset.StatusElementName);
                rootVisualElement.Q<Label>(installAsset.NameElementName).text = installAsset.DisplayName;
            }

            rootVisualElement.Q<Label>("setup-subtitle").text = UITKEffectsLocalization.Get("subtitle");
            rootVisualElement.Q<Label>("setup-description").text = UITKEffectsLocalization.Get("description");
            rootVisualElement.Q<Label>("install-location-eyebrow").text = UITKEffectsLocalization.Get("install_location");
            rootVisualElement.Q<Label>("ui-builder-assets-eyebrow").text = UITKEffectsLocalization.Get("ui_builder_assets");
            rootVisualElement.Q<Label>("sample-eyebrow").text = UITKEffectsLocalization.Get("sample_eyebrow");
            rootVisualElement.Q<Label>("sample-title").text = UITKEffectsLocalization.Get("sample_title");
            rootVisualElement.Q<Label>("sample-description").text = UITKEffectsLocalization.Get("sample_description");
            _openFolderButton.text = UITKEffectsLocalization.Get("show_installed_assets");
            _showSampleButton.text = UITKEffectsLocalization.Get("sample_show");

            var showAtStartupToggle = rootVisualElement.Q<Toggle>("show-at-startup-toggle");
            showAtStartupToggle.label = UITKEffectsLocalization.Get("show_at_startup");
            showAtStartupToggle.SetValueWithoutNotify(
                EditorPrefs.GetBool(ShowAtStartupKey, true));
            showAtStartupToggle.RegisterValueChangedCallback(evt =>
                EditorPrefs.SetBool(ShowAtStartupKey, evt.newValue));

            var closeButton = rootVisualElement.Q<Button>("close-button");
            closeButton.text = UITKEffectsLocalization.Get("close");

            _installButton.clicked += InstallDefinitions;
            _openFolderButton.clicked += ShowInstalledAssets;
            _importSampleButton.clicked += ImportRecommendedSample;
            _showSampleButton.clicked += ShowImportedSample;
            closeButton.clicked += Close;

            RefreshStatus();
            RefreshSampleStatus();
        }

        private void InstallDefinitions()
        {
            var installedCount = 0;
            var failures = new List<string>();

            try
            {
                foreach (var installAsset in InstallAssets)
                {
                    EnsureAssetFolder(installAsset.TargetFolder);

                    if (AssetDatabase.LoadMainAssetAtPath(installAsset.TargetPath) != null)
                        continue;

                    if (AssetDatabase.CopyAsset(installAsset.SourcePath, installAsset.TargetPath))
                        installedCount++;
                    else
                        failures.Add(installAsset.FileName);
                }

                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
                failures.Add(exception.Message);
            }

            RefreshStatus();

            if (failures.Count > 0)
            {
                ShowResult(
                    UITKEffectsLocalization.Get("result_failures", string.Join(", ", failures)),
                    true);
                return;
            }

            ShowResult(
                installedCount > 0
                    ? UITKEffectsLocalization.Get("result_installed", installedCount)
                    : UITKEffectsLocalization.Get("result_all_installed"),
                false);
            ShowInstalledAssets();
        }

        private void RefreshStatus()
        {
            var installedCount = 0;

            foreach (var installAsset in InstallAssets)
            {
                var installed =
                    AssetDatabase.LoadMainAssetAtPath(installAsset.TargetPath) != null;
                var statusLabel = _statusLabels[installAsset.StatusElementName];

                statusLabel.text = installed
                    ? UITKEffectsLocalization.Get("installed")
                    : UITKEffectsLocalization.Get("missing");
                statusLabel.EnableInClassList("status-installed", installed);
                statusLabel.EnableInClassList("status-missing", !installed);

                if (installed)
                    installedCount++;
            }

            var complete = installedCount == InstallAssets.Length;
            _installButton.text = complete
                ? UITKEffectsLocalization.Get("install_button_complete")
                : installedCount > 0
                    ? UITKEffectsLocalization.Get("install_button_partial")
                    : UITKEffectsLocalization.Get("install_button_default");
            _installButton.SetEnabled(!complete);
            _openFolderButton.style.display = complete || installedCount > 0
                ? DisplayStyle.Flex
                : DisplayStyle.None;
        }

        private void ShowInstalledAssets()
        {
            var folder = AssetDatabase.LoadAssetAtPath<DefaultAsset>(InstallRoot);
            if (folder == null)
                return;

            Selection.activeObject = folder;
            EditorGUIUtility.PingObject(folder);
        }

        private void ImportRecommendedSample()
        {
            if (!TryGetRecommendedSample(out var sample))
            {
                ShowResult(UITKEffectsLocalization.Get("sample_not_found"), true);
                return;
            }

            var importOptions = Sample.ImportOptions.HideImportWindow;
            if (sample.isImported)
            {
                var overwrite = EditorUtility.DisplayDialog(
                    UITKEffectsLocalization.Get("sample_reimport_title"),
                    UITKEffectsLocalization.Get("sample_reimport_message"),
                    UITKEffectsLocalization.Get("sample_reimport_title"),
                    UITKEffectsLocalization.Get("close"));
                if (!overwrite)
                    return;

                importOptions |= Sample.ImportOptions.OverridePreviousImports;
            }

            sample.Import(importOptions);
            AssetDatabase.Refresh();
            RefreshSampleStatus();
            ShowResult(
                UITKEffectsLocalization.Get(
                    "sample_imported",
                    RecommendedComponentName,
                    RecommendedUnityLabel),
                false);
            ShowImportedSample();
        }

        private void RefreshSampleStatus()
        {
            var imported = TryGetRecommendedSample(out var sample) && sample.isImported;
            _importSampleButton.text = UITKEffectsLocalization.Get(
                imported ? "sample_reimport" : "sample_import");
            _showSampleButton.style.display = imported ? DisplayStyle.Flex : DisplayStyle.None;
        }

        private void ShowImportedSample()
        {
            if (!TryGetRecommendedSample(out var sample) || !sample.isImported)
                return;

            var folder = AssetDatabase.LoadAssetAtPath<DefaultAsset>(sample.importPath);
            if (folder == null)
                return;

            Selection.activeObject = folder;
            EditorGUIUtility.PingObject(folder);
        }

        private static bool TryGetRecommendedSample(out Sample recommendedSample)
        {
            var packageInfo = UnityEditor.PackageManager.PackageInfo.FindForAssetPath(
                $"Packages/{PackageName}");
            if (packageInfo != null)
            {
                foreach (var sample in Sample.FindByPackage(packageInfo.name, packageInfo.version))
                {
                    if (sample.displayName == RecommendedSampleName)
                    {
                        recommendedSample = sample;
                        return true;
                    }
                }
            }

            recommendedSample = default;
            return false;
        }

        private static string RecommendedSampleName =>
            IsUnity65OrNewer ? Unity65SampleName : Unity63SampleName;

        private static string RecommendedUnityLabel =>
            IsUnity65OrNewer ? "6.5+" : "6.3 / 6.4";

        private static string RecommendedComponentName =>
            IsUnity65OrNewer ? "PanelRenderer" : "UIDocument";

        private static bool IsUnity65OrNewer
        {
            get
            {
                var versionParts = Application.unityVersion.Split('.');
                if (versionParts.Length < 2 ||
                    !int.TryParse(versionParts[0], out var major) ||
                    !int.TryParse(versionParts[1], out var minor))
                    return false;

                return major > 6000 || major == 6000 && minor >= 5;
            }
        }

        private void ShowResult(string message, bool isError)
        {
            _resultMessage.text = message;
            _resultMessage.style.display = DisplayStyle.Flex;
            _resultMessage.EnableInClassList("result-error", isError);
        }

        private static void EnsureAssetFolder(string folderPath)
        {
            var segments = folderPath.Split('/');
            var currentPath = segments[0];

            for (var index = 1; index < segments.Length; index++)
            {
                var nextPath = $"{currentPath}/{segments[index]}";
                if (!AssetDatabase.IsValidFolder(nextPath))
                    AssetDatabase.CreateFolder(currentPath, segments[index]);

                currentPath = nextPath;
            }
        }

        private sealed class InstallAssetInfo
        {
            internal InstallAssetInfo(
                string sourceFolder,
                string targetFolder,
                string fileName,
                string statusElementName,
                string nameElementName,
                string displayName)
            {
                SourceFolder = sourceFolder;
                TargetFolder = targetFolder;
                FileName = fileName;
                StatusElementName = statusElementName;
                NameElementName = nameElementName;
                DisplayName = displayName;
            }

            internal string SourceFolder { get; }
            internal string TargetFolder { get; }
            internal string FileName { get; }
            internal string StatusElementName { get; }
            internal string NameElementName { get; }
            internal string DisplayName { get; }
            internal string SourcePath => $"{SourceFolder}/{FileName}";
            internal string TargetPath => $"{TargetFolder}/{FileName}";
        }
    }

    [InitializeOnLoad]
    internal static class UITKEffectsSetupStartup
    {
        private const string SessionKey = "NKStudio.UITKEffects.SetupShownThisSession";

        static UITKEffectsSetupStartup()
        {
            EditorApplication.delayCall += ShowSetupIfNeeded;
        }

        private static void ShowSetupIfNeeded()
        {
            if (Application.isBatchMode || EditorApplication.isPlayingOrWillChangePlaymode)
                return;

            if (SessionState.GetBool(SessionKey, false))
                return;

            SessionState.SetBool(SessionKey, true);

            if (!EditorPrefs.GetBool(UITKEffectsSetupWindow.ShowAtStartupKey, true))
                return;

            if (UITKEffectsSetupWindow.AreAllAssetsInstalled())
                return;

            UITKEffectsSetupWindow.ShowSetupWindow();
        }
    }
}
