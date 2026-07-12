# UITK Effects

UI Toolkit용 커스텀 포스트프로세싱 필터 + 그라디언트 머티리얼 모음. 순수 애셋(셰이더/머티리얼/`FilterFunctionDefinition`)으로만 구성되어 있으며 런타임 C# 코드는 없습니다.

패키지 경로: `Packages/com.c8c64457-4c6f-4bde-933c-4aab3ac68aec.uitkeffects`

## 폴더 구조

```
├── Art/
│   ├── Materials/   — 셰이더 머티리얼 (DropShadow, InnerShadow, OuterGlow, Outline, Gradient)
│   └── Shaders/     — 셰이더 소스
└── Scripts/
    └── Runtime/
        ├── com.nkstudio.uitk-effects.runtime.asmdef
        └── Filters/ — FilterFunctionDefinition .asset
```

## 포함된 이펙트

| 이펙트 | 종류 | 파라미터 | asset 경로 (패키지 기준) |
|---|---|---|---|
| Drop Shadow | filter | `offset-x` `offset-y` `blur-radius` `color` | `Scripts/Runtime/Filters/DropShadowFilter.asset` |
| Inner Shadow | filter | `offset-x` `offset-y` `blur-radius` `color` | `Scripts/Runtime/Filters/InnerShadowFilter.asset` |
| Outer Glow | filter | `radius` `intensity` `color` | `Scripts/Runtime/Filters/OuterGlowFilter.asset` |
| Outline | filter | `width` `color` `mode` (0=Outside 1=Center 2=Inside) | `Scripts/Runtime/Filters/OutlineFilter.asset` |
| Gradient | 머티리얼 (`-unity-material`) | `_ColorStart` `_ColorEnd` `_Angle` `_Steps` | `Art/Materials/Gradient.mat` |

## 사용법

### 필터 (Drop Shadow / Inner Shadow / Outer Glow / Outline)

USS (패키지 애셋은 `/Packages/...` 경로로 참조):
```css
.my-element {
    filter: filter("/Packages/com.c8c64457-4c6f-4bde-933c-4aab3ac68aec.uitkeffects/Scripts/Runtime/Filters/DropShadowFilter.asset" 8 8 10 rgba(0, 0, 0, 0.5));
}
```

> UI Builder에서 필터/머티리얼을 드래그해 지정하면 위 경로 대신 GUID 기반 `url("project://database/...")` 형태로 자동 기록됩니다. 애셋을 옮겨도 GUID 참조는 깨지지 않습니다.

여러 필터를 체인으로 걸 수도 있습니다 (단, 아래 주의사항 참고):
```css
.my-element {
    filter: filter("...OutlineFilter.asset" 6 rgb(255,210,0) 0) filter("...DropShadowFilter.asset" 8 8 10 rgba(0,0,0,0.5));
}
```

C#:
```csharp
var def = AssetDatabase.LoadAssetAtPath<FilterFunctionDefinition>(
    "Packages/com.c8c64457-4c6f-4bde-933c-4aab3ac68aec.uitkeffects/Scripts/Runtime/Filters/OutlineFilter.asset");
var f = new FilterFunction(def);
f.AddParameter(new FilterParameter(6f));
f.AddParameter(new FilterParameter(Color.yellow));
f.AddParameter(new FilterParameter(0f));
element.style.filter = new List<FilterFunction> { f };
```

### Gradient (머티리얼)

필터가 아니라 `-unity-material`로 적용합니다. **서브트리 전체가 아니라 해당 요소 자신에게만** 적용되므로, 자식 텍스트/이미지가 그라디언트 색에 먹히지 않습니다.

```css
.my-box {
    background-color: white; /* 알파 마스크 역할 */
    -unity-material: url("/Packages/com.c8c64457-4c6f-4bde-933c-4aab3ac68aec.uitkeffects/Art/Materials/Gradient.mat")
        prop("_ColorStart" rgb(100, 50, 230))
        prop("_ColorEnd" rgb(255, 130, 50))
        prop("_Angle" 45)
        prop("_Steps" 0);
}
```

- `_Angle`: 0 = 왼쪽→오른쪽, 시계방향 증가
- `_Steps`: 0이면 부드러운 그라디언트, N(2 이상)이면 N단계로 끊어진 밴드 그라디언트

`-unity-material`은 **상속되는 프로퍼티**이므로, 자식 요소가 그라디언트 영향을 받지 않게 하려면 자식에 `-unity-material: none;`을 명시하세요.

같은 `FilterFunctionDefinition` 애셋을 한 요소의 `filter:` 체인 안에서 여러 번 참조해도(예: 네오모피즘처럼 밝은 그림자+어두운 그림자를 DropShadow로 두 번 거는 경우) 정상 동작합니다.

```css
filter: filter("...DropShadowFilter.asset" 20 20 70 rgba(0,0,0,.3))
        filter("...DropShadowFilter.asset" -20 -20 70 rgba(255,255,255,.7));
```

## Unity 6.5 참고사항

이 프로젝트에서는 `UIDocument` 대신 `PanelRenderer` 컴포넌트를 사용합니다. 필터/머티리얼 적용 방식 자체는 동일하게 동작합니다.
