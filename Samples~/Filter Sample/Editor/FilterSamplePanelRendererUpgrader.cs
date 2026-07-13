using System;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UIElements;

namespace NKStudio.UITKEffects.Samples.Editor
{
    // The Filter Sample scene ships with UIDocument so it opens correctly on
    // this package's minimum supported Unity version (6.3), where the
    // PanelRenderer component does not exist. On Unity 6.5+, where
    // PanelRenderer is available, this automatically swaps the sample's
    // UIDocument for an equivalent PanelRenderer, so customers on 6.5+ see the
    // PanelRenderer-based setup without shipping a second, version-specific scene.
    //
    // PanelRenderer is referenced purely via reflection (never as a compile-time
    // type) so this script still compiles on Unity 6.3/6.4, where the type does
    // not exist — the version check below simply no-ops there.
    [InitializeOnLoad]
    internal static class FilterSamplePanelRendererUpgrader
    {
        private const string SampleSceneName = "FilterSample";
        private const string PanelRendererTypeName =
            "UnityEngine.UIElements.PanelRenderer, UnityEngine.UIElementsModule";

        static FilterSamplePanelRendererUpgrader()
        {
            // Handle scenes opened after this script is live.
            EditorSceneManager.sceneOpened += OnSceneOpened;

            // Handle the race where the sample scene is opened *before* this
            // script has compiled/registered (e.g. the user double-clicks the
            // scene right after importing the sample). This static constructor
            // re-runs on every domain reload — including the one triggered by
            // compiling this very script — so once it does, sweep the already
            // open scenes too. Deferred to delayCall so the scene and its assets
            // are fully loaded before we touch them.
            EditorApplication.delayCall += UpgradeOpenScenes;
        }

        private static void OnSceneOpened(Scene scene, OpenSceneMode mode)
        {
            var panelRendererType = ResolvePanelRendererType();
            if (panelRendererType == null)
                return; // Unity 6.3/6.4: PanelRenderer doesn't exist, keep UIDocument as shipped.

            TryUpgradeScene(scene, panelRendererType);
        }

        private static void UpgradeOpenScenes()
        {
            var panelRendererType = ResolvePanelRendererType();
            if (panelRendererType == null)
                return;

            for (var i = 0; i < SceneManager.sceneCount; i++)
                TryUpgradeScene(SceneManager.GetSceneAt(i), panelRendererType);
        }

        private static Type ResolvePanelRendererType()
        {
            return Type.GetType(PanelRendererTypeName);
        }

        private static void TryUpgradeScene(Scene scene, Type panelRendererType)
        {
            if (!scene.IsValid() || !scene.isLoaded || scene.name != SampleSceneName)
                return;

            foreach (var root in scene.GetRootGameObjects())
            {
                var uiDocument = root.GetComponentInChildren<UIDocument>(true);
                if (uiDocument != null)
                    UpgradeToPanelRenderer(uiDocument, panelRendererType);
            }
        }

        private static void UpgradeToPanelRenderer(UIDocument uiDocument, Type panelRendererType)
        {
            var go = uiDocument.gameObject;
            var panelSettings = uiDocument.panelSettings;
            var sourceAsset = uiDocument.visualTreeAsset;

            Undo.DestroyObjectImmediate(uiDocument);
            var panelRenderer = Undo.AddComponent(go, panelRendererType);

            var serializedObject = new SerializedObject(panelRenderer);
            serializedObject.FindProperty("m_PanelSettings").objectReferenceValue = panelSettings;
            serializedObject.FindProperty("sourceAsset").objectReferenceValue = sourceAsset;
            serializedObject.ApplyModifiedPropertiesWithoutUndo();

            EditorSceneManager.MarkSceneDirty(go.scene);
            Debug.Log("[UITK Effects] Filter Sample: upgraded UIDocument to PanelRenderer for Unity 6.5+.");
        }
    }
}
