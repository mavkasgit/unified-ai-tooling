---
name: pytest-writer
description: >
  Писать, дополнять и чинить pytest-тесты для FastAPI + SQLAlchemy async backend.
  Используй этот скилл всякий раз, когда пользователь просит: написать тест для эндпоинта
  или модуля, покрыть тестами файл, добавить тест к существующему test_*.py, разобраться
  почему падает тест, создать _make_*-хелперы, или говорит «покрой это тестами».
  Также триггерится на «напиши тест», «добавь тест», «почему падает тест», «покрой тестами».
---

# pytest-writer

Скилл для написания backend-тестов на стеке FastAPI + SQLAlchemy (async) + PostgreSQL + Pydantic v2.

## Шаг 0 — Всегда читай код перед написанием тестов

Перед тем как писать что-либо, **обязательно прочитай**:

1. Сам тестируемый модуль (роутер, сервис, модель)
2. Существующий `test_<module>.py`, если он есть — чтобы не дублировать и следовать стилю
3. `conftest.py` — чтобы знать доступные фикстуры

```bash
# Найти нужные файлы
find . -name "*.py" | grep -E "(router|service|model)" | grep -i <module>
find . -name "conftest.py"
find . -name "test_<module>.py"
```

Не пиши тест пока не прочитал код. Даже если пользователь описал логику — читай файл сам.

---

## Приоритеты при написании тестов

В порядке важности:

1. **Бизнес-логика и граничные случаи** — что происходит при невалидных данных, пустом результате, отсутствии связанных записей, нулевых значениях
2. **Статус-коды** — 200, 201, 400, 404, 422 и другие ожидаемые коды для каждого сценария
3. **`_make_*` хелперы** — изолировать создание тестовых данных в именованные функции
4. **Именование** — следовать конвенции проекта

---

## Структура одного теста

```python
@pytest.mark.asyncio
async def test_<что_проверяет>_<сценарий>(client, session) -> None:
    # 1. Arrange — создать данные через _make_* хелперы
    product = await _make_product(session)
    
    # 2. Act — вызов эндпоинта или сервисной функции
    response = await client.get(f"/api/.../{product.id}")
    
    # 3. Assert — проверить конкретные значения, не просто "not None"
    assert response.status_code == 200
    data = response.json()
    assert data["sku"] == "FG-TEST"
    assert len(data["items"]) == 3
```

### Именование функций

```
test_<сущность>_<действие>_<сценарий>

# Примеры:
test_rows_detail_returns_not_started_for_new_position
test_orders_create_returns_422_on_missing_sku
test_plan_service_groups_combined_steps_correctly
```

---

## _make_* хелперы

Всегда создавай хелперы для подготовки данных. Они живут в том же файле, вверху, с префиксом `_make_`:

```python
async def _make_product(session, sku: str = "FG-TEST") -> Product:
    product = Product(sku=sku, name="Test Product")
    session.add(product)
    await session.flush()
    return product

async def _make_plan_with_positions(
    session,
    n_positions: int = 2,
) -> tuple[Plan, list[Position]]:
    plan = Plan(name="Test Plan")
    session.add(plan)
    await session.flush()
    positions = [
        Position(plan_id=plan.id, quantity=10)
        for _ in range(n_positions)
    ]
    session.add_all(positions)
    await session.flush()
    return plan, positions
```

**Правила хелперов:**
- Дефолтные значения — нейтральные (`"FG-TEST"`, `10`, `1`)
- `await session.flush()` после добавления — чтобы получить `id` без коммита
- Возвращать объект(ы) ORM, а не id
- Не делать `session.commit()` внутри хелпера — тест сам решает когда коммитить

---

## Фикстуры

Доступны через параметры теста (из `conftest.py`):

- `client` — async HTTP-клиент, знает префикс `/api/`
- `session` — `AsyncSession`, автоматически откатывается после каждого теста

Если нужна фикстура которой нет — предложи добавить в `conftest.py` и покажи код.

---

## Паттерны по типу теста

### API-эндпоинт (happy path + граничные случаи)

```python
# Happy path
async def test_positions_list_returns_all_positions(client, session):
    plan, positions = await _make_plan_with_positions(session, n_positions=3)
    await session.commit()
    
    response = await client.get(f"/api/plans/{plan.id}/positions")
    assert response.status_code == 200
    assert len(response.json()) == 3

# Граничный случай — пустой список
async def test_positions_list_returns_empty_for_plan_without_positions(client, session):
    plan = await _make_plan(session)
    await session.commit()
    
    response = await client.get(f"/api/plans/{plan.id}/positions")
    assert response.status_code == 200
    assert response.json() == []

# Граничный случай — не найден
async def test_positions_list_returns_404_for_missing_plan(client, session):
    response = await client.get("/api/plans/99999/positions")
    assert response.status_code == 404
```

### Сервисная функция (напрямую, без HTTP)

```python
async def test_group_steps_merges_combined_operations(session):
    steps = await _make_route_steps(session, operations=["PRESS", "PRESS", "BEND"])
    
    result = group_combined_steps(steps)
    
    assert len(result) == 2  # было 3, стало 2
    combined = next(s for s in result if "/" in s.operation_name)
    assert combined.operation_name == "PRESS / PRESS"
```

### Проверка payload/резолвинга

```python
async def test_position_detail_resolves_operation_from_source_payload(client, session):
    position = await _make_position(session)
    position.source_payload = {"operation_code": "PRESS_WINDOW"}
    await session.commit()
    
    response = await client.get(f"/api/positions/{position.id}")
    assert response.status_code == 200
    stage = next(s for s in response.json()["stages"] if s["type"] == "press")
    assert stage["operation_code"] == "PRESS_WINDOW"
```

---

## Чего не делать

| Плохо | Хорошо |
|-------|--------|
| `assert data["field"] is not None` | `assert data["field"] == "expected_value"` |
| Зависимость от seed-данных из БД | Создавать данные в тесте через `_make_*` |
| Один тест проверяет 5 разных вещей | Один тест — один сценарий |
| `session.commit()` в середине arrange без причины | `session.flush()` для получения id, `commit()` только перед Act |
| `time.sleep()` | `await asyncio.sleep()` или переосмыслить подход |

---

## Запуск и отладка

```bash
# Из директории с conftest.py и pytest.ini:
pytest tests/test_<module>.py -v

# Один тест
pytest tests/test_<module>.py::test_name -v

# Если 0 тестов собрано — проверить импорты
pytest --collect-only tests/test_<module>.py -v

# Вывод в файл (не использовать 2>&1 | head — символ 2 может стать аргументом pytest)
pytest -v > /tmp/test_out.txt 2>&1
cat /tmp/test_out.txt
```

**Частые причины падений:**
- Не активирован venv
- Ошибка импорта в тесте или в тестируемом модуле
- Запуск не из той директории (нужна папка с `conftest.py`)
- `await session.flush()` пропущен перед использованием `id`
- Забыт `@pytest.mark.asyncio` на async-тесте
