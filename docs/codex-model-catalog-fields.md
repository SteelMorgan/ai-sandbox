# Codex `model_catalog_json`: обязательные и опциональные поля

Источник схемы: `ModelInfo` в `codex-rs/protocol/src/openai_models.rs:224`.

## 1) Какие поля обязательны

Ниже поля, которые в `ModelInfo` не являются `Option<_>` и не имеют `#[serde(default)]`, поэтому их лучше считать обязательными для стабильного парсинга:

- `slug` (`String`) — внутренний ID модели, по нему модель выбирается и отправляется в API.
- `display_name` (`String`) — отображаемое имя в UI (`/models`, `/model`).
- `supported_reasoning_levels` (`Vec<ReasoningEffortPreset>`) — какие уровни reasoning доступны в шаге выбора effort.
- `shell_type` (`ConfigShellToolType`) — тип/режим shell-инструмента, который объявлен для модели.
- `visibility` (`ModelVisibility`) — показывать ли модель в picker (`list`) или скрывать.
- `supported_in_api` (`bool`) — считать ли модель доступной для API-режима.
- `priority` (`i32`) — порядок сортировки и выбор дефолтной модели (меньше = выше приоритет).
- `base_instructions` (`String`) — базовый system/developer промпт для этой модели.
- `supports_reasoning_summaries` (`bool`) — поддерживает ли модель summaries reasoning.
- `support_verbosity` (`bool`) — поддерживает ли модель параметр verbosity.
- `truncation_policy` (`TruncationPolicyConfig`) — политика обрезки больших tool outputs (tokens/bytes + limit).
- `supports_parallel_tool_calls` (`bool`) — можно ли слать параллельные tool calls.
- `experimental_supported_tools` (`Vec<String>`) — список дополнительных/экспериментальных инструментов для модели.

См. поля структуры в `codex-rs/protocol/src/openai_models.rs:224`.

## 2) Какие поля опциональны

Опциональные через `Option<_>` или `#[serde(default)]`:

- `description` (`Option<String>`) — короткое описание модели в picker/UI.
- `default_reasoning_level` (`Option<ReasoningEffort>`) — effort по умолчанию, если пользователь явно не выбрал уровень.
- `availability_nux` (`Option<ModelAvailabilityNux>`) — onboarding/NUX-сообщение о доступности модели.
- `upgrade` (`Option<ModelInfoUpgrade>`) — данные о рекомендуемом апгрейде модели и текст миграции.
- `model_messages` (`Option<ModelMessages>`) — расширенные шаблоны инструкций (в т.ч. personality).
- `default_reasoning_summary` (`ReasoningSummary`, c `#[serde(default)]`) — формат summary reasoning по умолчанию (`auto/concise/detailed/none`).
- `default_verbosity` (`Option<Verbosity>`) — уровень verbosity по умолчанию (`low/medium/high`).
- `apply_patch_tool_type` (`Option<ApplyPatchToolType>`) — какой вариант apply_patch использовать (если задано).
- `context_window` (`Option<i64>`) — контекстное окно модели в токенах.
- `auto_compact_token_limit` (`Option<i64>`) — порог авто-компакта контекста (если не задан, вычисляется из context_window).
- `effective_context_window_percent` (`i64`, default через `default_effective_context_window_percent`) — доля usable-контекста после сервисных накладных расходов.
- `input_modalities` (`Vec<InputModality>`, default через `default_input_modalities`) — какие типы входа поддерживаются (`text`, `image`).
- `prefer_websockets` (`bool`, c `#[serde(default)]`) — предпочтительно ли использовать websocket transport.

Служебное поле `used_fallback_model_metadata` не нужно указывать в JSON (`skip_deserializing`) — `openai_models.rs:267`.

## 3) Как заполнено в дефолтном каталоге Codex (`core/models.json`)

Проверка по `codex-rs/core/models.json` (12 моделей):

Всегда присутствуют (12/12):
- `slug`, `display_name`, `description`, `default_reasoning_level`, `supported_reasoning_levels`
- `shell_type`, `visibility`, `supported_in_api`, `priority`
- `upgrade`, `base_instructions`, `model_messages`
- `supports_reasoning_summaries`, `support_verbosity`, `default_verbosity`
- `apply_patch_tool_type`, `truncation_policy`, `supports_parallel_tool_calls`
- `context_window`, `experimental_supported_tools`, `input_modalities`, `prefer_websockets`

Обычно не задаются (используются дефолты/optional):
- `availability_nux` (0/12)
- `default_reasoning_summary` (0/12)
- `auto_compact_token_limit` (0/12)
- `effective_context_window_percent` (0/12)

Часто `null`:
- `upgrade` (часть моделей)
- `model_messages` (часть моделей)
- `default_verbosity` (часть моделей)
- `apply_patch_tool_type` (редко)

Пример дефолтной записи с реальными значениями: `codex-rs/core/models.json:20`.

## 4) Минимально безопасный шаблон для кастомной модели

```json
{
  "slug": "ag/gemini-3-flash",
  "display_name": "ag/gemini-3-flash",
  "supported_reasoning_levels": [
    { "effort": "none", "description": "No reasoning" }
  ],
  "shell_type": "shell_command",
  "visibility": "list",
  "supported_in_api": true,
  "priority": 17,
  "base_instructions": "You are Codex, based on GPT-5. You are running as a coding agent in the Codex CLI on a user's computer.",
  "supports_reasoning_summaries": false,
  "support_verbosity": false,
  "truncation_policy": { "mode": "tokens", "limit": 10000 },
  "supports_parallel_tool_calls": false,
  "experimental_supported_tools": []
}
```

Рекомендуется добавить также:
- `default_reasoning_level: "none"`
- `input_modalities: ["text", "image"]`
- `context_window: 272000`

Чтобы поведение `/models` и выбора модели было ближе к штатному каталогу.
