# Magical Idols — 팬 적 시스템

Godot **4.7.2**, GDScript. 일반팬과 안티팬의 재사용 가능한 시스템입니다.
UI, 테스트 씬·스크립트·이미지 및 메인 씬을 제외한 게임 시스템입니다.
실제 게임 씬에서 아래 구성 요소를 연결해 사용합니다.

| 팬클럽 | 이동 | 공격 | HP | 속도 | 인구 비용 |
| --- | --- | --- | --- | --- | --- |
| 일반팬 | 진영 전방으로 직진 | 전방 1발 / 1.0초 | 3 | 68 px/s | 1 |
| 안티팬 | 상대 플레이어 추적, 48px 앞 정지 | 발사 순간 상대 위치로 1발 / 1.3초 | 4 | 82 px/s | 2 |

안티팬의 세부 패턴과 두 팬의 수치는 설계 초안에 확정값이 없어 정한 **프로토타입 값**입니다.
안티팬의 탄환은 발사 후 유도되지 않습니다. 각 `.tres`를 Inspector에서 열어 수치나 행동 씬을 바꿀 수 있습니다.

## 구현 구조

```text
data/fanclubs/*.tres          팬클럽 데이터, 기본 수치와 행동 조합
scenes/fan/fan.tscn           두 종류가 공유하는 팬 씬
scripts/fan/fan.gd           개별 HP, 이동 실행, 발사 요청, 사망/이탈
behaviors/movement/*.tscn    직진 / 상대 추적
behaviors/attack/*.tscn      전방 발사 / 조준 발사
scripts/team/               라운드 로빈 생성, 인구 예약 및 반환
scripts/projectile/         탄환 생성, 진영 판정, 피해, 수명
scripts/ability/            향후 특수 능력을 위한 베이스
```

새 팬클럽은 `FanClubData` 리소스에서 기존 이동/공격 씬을 조합해 추가합니다. 공통 `Fan`에는 팬클럽 ID별 행동 분기가 없습니다.
`FanClubData`에는 실행 중 상태를 쓰지 않습니다. 팬 초기화 값과 신호를 트리 진입 전에 지정하고, 탄환은 팬과 독립적인 `ProjectileSpawner`가 소유합니다.
사망은 `died → despawned`, 맵 이탈은 `despawned`만 발생하며 인구는 정확히 한 번 반환합니다.

진영당 인구 상한은 **16**이며, 마릿수 대신 살아 있는 팬의 인구 비용 합계를 사용합니다.
일반팬과 안티팬에는 별도 특수 능력이 없습니다.

## 게임 씬 연결

`TeamController`를 트리에 추가하기 전에 다음 값을 설정합니다.

- `team_id`: 1은 오른쪽으로, 2는 왼쪽으로 전진합니다.
- `owned_clubs`: `data/fanclubs/`의 `FanClubData` 리소스 목록입니다.
- `enemy_player`: 추적할 상대 `CharacterBody2D`입니다. 데모 플레이어 클래스에 의존하지 않습니다.
- `fan_container`: 생성한 팬을 담을 `Node2D`입니다.
- `projectile_spawner`: 게임 씬에 추가한 `ProjectileSpawner`입니다.
- `arena_rect`: 월드 좌표 기준 활동 영역입니다. 기본값은 `(0, 0, 1280, 720)`입니다.

트리에 추가되면 타이머가 팬을 자동 생성합니다. 즉시 첫 팬이 필요하면 `try_spawn()`을 호출합니다.
팬과 탄환 씬에는 충돌체, 로직과 이미지를 연결할 `Sprite2D`가 있습니다.

피격 가능한 캐릭터는 `team_id`와 `take_damage(amount: int)`를 제공해야 합니다.
`is_combat_active() -> bool`을 제공하면 비활성 상태에서 추적과 피격을 건너뜁니다.
캐릭터는 물리 레이어 1, 팬은 레이어 2를 사용하고 탄환은 두 레이어를 감지합니다.
아군 탄환은 아군을 통과합니다. 팬끼리 몸으로 밀지는 않습니다.

## 스프라이트 연결

1. 사용할 PNG를 프로젝트 폴더 안에 넣습니다.
2. `data/fanclubs/normal_fan.tres`를 선택하고 Inspector의 **Visuals → Sprite Texture**에 일반팬 PNG를 넣습니다.
3. `anti_fan.tres`의 같은 항목에는 안티팬 PNG를 넣습니다.
4. 크기는 각 데이터의 **Sprite Scale**로 조정합니다. 충돌 크기는 `fan.tscn`의 `CollisionShape2D`에서 조정합니다.

팬이 생성되면 공통 `fan.tscn`의 `Sprite2D`에 해당 팬클럽 이미지가 자동 적용됩니다.
팬클럽 이미지가 비어 있으면 `fan.tscn`의 `Sprite2D`에 직접 설정한 기본 이미지를 사용합니다.
팬 씬을 게임 씬에 배치하는 경우 루트의 **Club** 항목에 사용할 팬클럽 `.tres`를 지정합니다.
탄환 이미지는 `scenes/projectile/normal_bullet.tscn`을 열고 **Sprite2D → Texture**에 넣습니다.
현재는 정적 이미지 연결이며, 걷기 등 프레임 애니메이션은 별도로 연결해야 합니다.

## 리소스 확인

Godot 실행 파일을 `godot`으로 사용할 수 있는 셸에서 프로젝트 폴더를 기준으로 실행합니다.

```powershell
godot --headless --path . --editor --import --quit
```
