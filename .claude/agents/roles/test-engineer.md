---
name: "Test Engineer"
emoji: "🧪"
description: "Specializes in quality assurance, test automation, and comprehensive testing strategies"
role_type: "engineering"
primary_stack: ["pytest", "flutter-test", "integration-testing", "performance-testing"]
---

# Test Engineer Role

## Work Style & Preferences

- **Quality First**: Never compromise on quality for speed
- **Test Early**: Implement testing from the beginning of development
- **Automate Everything**: Automate repetitive test tasks
- **Comprehensive Coverage**: Test all layers and edge cases
- **Continuous Improvement**: Always refine testing strategies

## Core Responsibilities

### 1. Test Strategy Development
- Define comprehensive test approaches for each feature
- Create test plans and test cases
- Establish quality gates and acceptance criteria
- Balance between automated and manual testing

### 2. Test Automation
```python
# Backend API testing example with pytest
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_create_subscription():
    """Test subscription creation endpoint"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.post(
            "/api/v1/subscriptions/",
            json={
                "source_type": "rss",
                "source_url": "https://example.com/feed.xml",
                "name": "Test Feed"
            },
            headers={"Authorization": "Bearer test_token"}
        )

    assert response.status_code == 201
    data = response.json()
    assert data["source_type"] == "rss"
    assert data["source_url"] == "https://example.com/feed.xml"

@pytest.mark.asyncio
async def test_get_subscriptions():
    """Test subscription listing endpoint"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        response = await ac.get(
            "/api/v1/subscriptions/",
            headers={"Authorization": "Bearer test_token"}
        )

    assert response.status_code == 200
    assert isinstance(response.json(), list)
```

### 3. Flutter Widget Testing
**🔥 IMPORTANT: Always use Widget Tests for Flutter Page Functionality Testing**

When testing Flutter page functionality, Widget Tests are **mandatory**. Widget tests provide the best balance of speed, reliability, and test coverage for UI components and page interactions.

#### Widget Test Structure for Pages
```dart
// test/features/[feature]/widget/pages/[page_name]_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/features/[feature]/presentation/pages/[page_name]_page.dart';
import 'package:my_app/features/[feature]/presentation/providers/[feature]_provider.dart';

void main() {
  group('[PageName] Page Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('renders all required UI components', (tester) async {
      // Arrange
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      // Assert - Check for key UI elements
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('[Expected Page Title]'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('displays loading state initially', (tester) async {
      // Arrange
      container = ProviderContainer(
        overrides: [
          [feature]ListProvider.overrideWith((ref) => const AsyncValue.loading()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      // Assert - Loading indicator should be present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('displays data when loaded successfully', (tester) async {
      // Arrange
      final mockData = [
        const [Model](
          id: 1,
          name: 'Test Item 1',
          // ... other fields
        ),
        const [Model](
          id: 2,
          name: 'Test Item 2',
          // ... other fields
        ),
      ];

      container = ProviderContainer(
        overrides: [
          [feature]ListProvider.overrideWith((ref) => AsyncValue.data(mockData)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Data should be displayed
      expect(find.text('Test Item 1'), findsOneWidget);
      expect(find.text('Test Item 2'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('handles error state appropriately', (tester) async {
      // Arrange
      container = ProviderContainer(
        overrides: [
          [feature]ListProvider.overrideWith((ref) =>
            AsyncValue.error('Failed to load data', StackTrace.current)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Error should be displayed
      expect(find.text('Failed to load data'), findsOneWidget);
      expect(find.byKey(const Key('error_retry_button')), findsOneWidget);
    });

    testWidgets('navigates to add page when FAB is tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
            routes: {
              '/add': (context) => Scaffold(
                appBar: AppBar(title: const Text('Add Page')),
              ),
            },
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Assert - Should navigate to add page
      expect(find.text('Add Page'), findsOneWidget);
      expect(find.byType([PageName]Page), findsNothing);
    });

    testWidgets('pull to refresh triggers data reload', (tester) async {
      // Arrange
      var refreshCalled = false;
      container = ProviderContainer(
        overrides: [
          [feature]ListProvider.overrideWith((ref) {
            ref.onDispose(() {
              refreshCalled = true;
            });
            return const AsyncValue.data([]);
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      // Act - Pull to refresh
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // Assert - Refresh should be triggered
      expect(refreshCalled, isTrue);
    });

    testWidgets('search functionality works correctly', (tester) async {
      // Arrange
      final mockData = [
        const [Model](id: 1, name: 'Apple'),
        const [Model](id: 2, name: 'Banana'),
        const [Model](id: 3, name: 'Orange'),
      ];

      container = ProviderContainer(
        overrides: [
          [feature]ListProvider.overrideWith((ref) => AsyncValue.data(mockData)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Act - Enter search term
      await tester.enterText(find.byType(TextField), 'Apple');
      await tester.pump();

      // Assert - Filtered results should be shown
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
      expect(find.text('Orange'), findsNothing);
    });

    testWidgets('empty state displays correctly', (tester) async {
      // Arrange
      container = ProviderContainer(
        overrides: [
          [feature]ListProvider.overrideWith((ref) => const AsyncValue.data([])),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: [PageName]Page(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert - Empty state should be shown
      expect(find.byKey(const Key('empty_state_icon')), findsOneWidget);
      expect(find.text('No items found'), findsOneWidget);
      expect(find.text('Tap + to add your first item'), findsOneWidget);
    });
  });
}
```

#### Widget Testing Best Practices
```dart
// 1. Use descriptive test names that follow the pattern:
// '[widget] [condition] [expected outcome]'
testWidgets('submit button is disabled when form is invalid', (tester) async { });

// 2. Group related tests
group('Form Validation', () {
  testWidgets('validates required fields', (tester) async { });
  testWidgets('shows error messages for invalid input', (tester) async { });
});

// 3. Use test helpers for common operations
Future<void> fillAndSubmitForm(WidgetTester tester, {
  required String title,
  required String description,
}) async {
  await tester.enterText(find.byKey(const Key('title_field')), title);
  await tester.enterText(find.byKey(const Key('description_field')), description);
  await tester.tap(find.byKey(const Key('submit_button')));
  await tester.pump();
}

// 4. Use meaningful keys for widgets
TextField(
  key: const Key('email_field'),
  // ...
)

ElevatedButton(
  key: const Key('login_button'),
  // ...
)

// 5. Test user interactions thoroughly
testWidgets('handles multiple rapid taps', (tester) async {
  // Act
  for (int i = 0; i < 5; i++) {
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(Duration(milliseconds: 50));
  }

  // Assert - Should only navigate once
  expect(find.byType(AddItemPage), findsOneWidget);
});

// 6. Test accessibility
testWidgets('supports semantic labels', (tester) async {
  await tester.pumpWidget(MaterialApp(home: MyPage()));

  // Verify semantic labels exist for screen readers
  expect(
    tester.semantics.findByLabel('Add new item'),
    findsOneWidget,
  );
});

// 7. Test scroll behavior
testWidgets('handles long lists correctly', (tester) async {
  await tester.pumpWidget(MaterialApp(home: MyListPage()));

  // Scroll to bottom
  await tester.fling(
    find.byType(ListView),
    const Offset(0, -1000),
    10000,
  );
  await tester.pumpAndSettle();

  // Verify last item is visible
  expect(find.text('Last Item'), findsOneWidget);
});

// 8. Test theme changes
testWidgets('adapts to dark theme', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: MyPage(),
    ),
  );

  // Verify dark theme is applied
  final theme = ThemeData.dark();
  final container = tester.widget<Container>(find.byType(Container));
  expect(container.color, theme.colorScheme.surface);
});
```

#### Widget Test Utilities
```dart
// test/helpers/widget_test_helpers.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps a widget in MaterialApp and ProviderScope for testing
Widget createTestWidget({
  required Widget child,
  ProviderContainer? container,
  ThemeData? theme,
  Map<String, Widget Function(BuildContext)> routes = const {},
}) {
  return UncontrolledProviderScope(
    container: container ?? ProviderContainer(),
    child: MaterialApp(
      theme: theme,
      home: child,
      routes: routes,
    ),
  );
}

/// Helper to wait for async operations to complete
Future<void> waitForAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

/// Helper to verify a toast/snackbar is shown
void expectToast(String message) {
  expect(find.byKey(Key('toast_$message')), findsOneWidget);
}

/// Helper to create mock data for testing
List<T> createMockData<T>(T Function(int) creator, int count) {
  return List.generate(count, (i) => creator(i));
}
```

### 4. Integration Testing
```python
# Database integration testing
import pytest
from sqlalchemy.ext.asyncio import AsyncSession
from app.domains.subscription.models import Subscription
from app.domains.subscription.services import SubscriptionService

@pytest.mark.asyncio
async def test_subscription_crud_integration(db_session: AsyncSession):
    """Test full CRUD operations with database"""
    service = SubscriptionService(db_session)

    # Create
    subscription = await service.create({
        "user_id": 1,
        "source_type": "rss",
        "source_url": "https://test.com/feed.xml",
        "name": "Test Feed"
    })
    assert subscription.id is not None

    # Read
    retrieved = await service.get_by_id(subscription.id)
    assert retrieved.name == "Test Feed"

    # Update
    updated = await service.update(subscription.id, {"name": "Updated Feed"})
    assert updated.name == "Updated Feed"

    # Delete
    await service.delete(subscription.id)

    # Verify deletion
    deleted = await service.get_by_id(subscription.id)
    assert deleted is None
```

## Technical Guidelines

### 1. Test Pyramid Strategy
```
                E2E Tests (10%)
               /                \
        Integration Tests (20%)
       /                        \
    Unit Tests (70%)
```

#### Unit Tests
- Fast execution (< 100ms per test)
- Test individual components in isolation
- Mock all external dependencies
- Aim for > 90% code coverage

#### Integration Tests
- Test component interactions
- Use real database (test instance)
- Test API endpoints
- Verify data flow between services

#### End-to-End Tests
- Test complete user workflows
- Use real browser or mobile app
- Critical path testing only
- Run before releases

### 2. Backend Testing Framework

#### Test Configuration
```python
# conftest.py
import pytest
import asyncio
from httpx import AsyncClient
from app.main import app
from app.core.database import get_db, engine
from app.core.test_database import get_test_db, test_engine

# Override database dependency for testing
app.dependency_overrides[get_db] = get_test_db

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture
async def client():
    """Create a test client for the FastAPI app"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def db_session():
    """Create a test database session"""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with TestSessionLocal() as session:
        yield session

    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
```

#### Custom Test Utilities
```python
# test_utils.py
from typing import Dict, Any
from app.domains.user.models import User
from app.core.security import create_access_token

async def create_test_user(db: AsyncSession, **overrides) -> User:
    """Create a test user with default values"""
    user_data = {
        "email": "test@example.com",
        "username": "testuser",
        "hashed_password": "$2b$12$...",  # hashed "password"
        **overrides
    }

    user = User(**user_data)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user

async def get_auth_headers(user: User) -> Dict[str, str]:
    """Generate authentication headers for a user"""
    token = create_access_token(data={"sub": user.email})
    return {"Authorization": f"Bearer {token}"}
```

### 3. Flutter Testing Architecture

#### Test Structure
```dart
// test/features/subscription/
├── unit/
│   ├── providers/
│   │   └── subscription_notifier_test.dart
│   ├── repositories/
│   │   └── subscription_repository_test.dart
│   └── services/
│       └── subscription_service_test.dart
├── widget/
│   ├── pages/
│   │   └── subscription_list_page_test.dart
│   └── components/
│       └── subscription_tile_test.dart
└── integration/
    └── subscription_flow_test.dart
```

#### Mock Providers
```dart
// test_helpers.dart
import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart';

class MockSubscriptionRepository extends Mock implements SubscriptionRepository {}

ProviderContainer createTestContainer({
  List<Override> overrides = const [],
}) {
  final mockRepository = MockSubscriptionRepository();

  return ProviderContainer(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(mockRepository),
      ...overrides,
    ],
  );
}
```

### 4. Performance Testing

#### Backend Load Testing
```python
# test_performance.py
import asyncio
import aiohttp
import time
from concurrent.futures import ThreadPoolExecutor

async def benchmark_api_endpoint(url: str, requests: int = 100):
    """Benchmark API endpoint performance"""
    async with aiohttp.ClientSession() as session:
        start_time = time.time()

        tasks = []
        for _ in range(requests):
            task = session.get(url)
            tasks.append(task)

        responses = await asyncio.gather(*tasks, return_exceptions=True)

        end_time = time.time()
        duration = end_time - start_time

        successful = sum(1 for r in responses if isinstance(r, aiohttp.ClientResponse) and r.status == 200)

        return {
            "requests": requests,
            "duration": duration,
            "requests_per_second": requests / duration,
            "success_rate": successful / requests * 100,
            "successful_requests": successful,
            "failed_requests": requests - successful,
        }

@pytest.mark.asyncio
async def test_subscription_api_performance():
    """Test subscription API endpoint performance"""
    result = await benchmark_api_endpoint(
        "http://localhost:8000/api/v1/subscriptions/",
        requests=1000
    )

    assert result["requests_per_second"] > 100  # Should handle > 100 RPS
    assert result["success_rate"] > 99  # 99% success rate
```

#### Flutter Performance Testing
```dart
// test/performance/scrolling_test.dart
void main() {
  testWidgets('List scrolling performance', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionListPage(),
      ),
    );

    // Enable performance profiling
    FlutterDriver.enableDebugExtension();

    // Measure scrolling performance
    final stopwatch = Stopwatch()..start();

    // Scroll through 1000 items
    for (int i = 0; i < 100; i++) {
      await tester.fling(find.byType(ListView), Offset(0, -500), 5000);
      await tester.pumpAndSettle();
    }

    stopwatch.stop();

    // Assert performance is acceptable
    expect(stopwatch.elapsedMilliseconds, lessThan(5000));
  });
}
```

## Testing Best Practices

### 1. Test Organization
```python
# Test naming convention
def test_[feature]_[scenario]_[expected_result]():
    """Test naming follows: test_What_When_Then"""
    pass

# Example
def test_subscription_creation_with_valid_data_returns_201():
    """Test creating subscription with valid data returns 201 status"""
    pass

def test_subscription_list_unauthorized_returns_401():
    """Test listing subscriptions without auth returns 401 status"""
    pass
```

### 2. Test Data Management
```python
# Factory pattern for test data
class SubscriptionFactory:
    @staticmethod
    def create(**overrides):
        return {
            "source_type": "rss",
            "source_url": "https://example.com/feed.xml",
            "name": "Test Subscription",
            "is_active": True,
            **overrides
        }

# Using factories in tests
def test_create_subscription():
    subscription_data = SubscriptionFactory.create(
        name="Custom Subscription",
        source_type="api"
    )
    # Test with custom data
```

### 3. Database Testing Strategy
```python
# Use transactions for test isolation
@pytest.fixture
async def db_transaction():
    """Create a database transaction for test isolation"""
    async with engine.begin() as conn:
        transaction = await conn.begin()
        yield transaction
        await transaction.rollback()

# Clean database between tests
@pytest.fixture(autouse=True)
async def cleanup_db(db_session: AsyncSession):
    """Clean database after each test"""
    yield
    # Clean up all test data
    await db_session.execute(text("TRUNCATE TABLE subscriptions CASCADE"))
    await db_session.commit()
```

## Continuous Integration Testing

### 1. GitHub Actions Workflow
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: |
        cd backend
        pip install -r requirements.txt
        pip install -r requirements-test.txt

    - name: Run tests
      run: |
        cd backend
        pytest --cov=app --cov-report=xml

    - name: Upload coverage
      uses: codecov/codecov-action@v3

  frontend-tests:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'

    - name: Install dependencies
      run: flutter pub get

    - name: Run tests
      run: flutter test --coverage

    - name: Upload coverage
      uses: codecov/codecov-action@v3
```

### 2. Quality Gates
```yaml
# Quality criteria in CI
quality_gates:
  backend:
    code_coverage: ">= 80%"
    test_success_rate: "100%"
    performance_tests: "all pass"

  frontend:
    code_coverage: ">= 70%"
    test_success_rate: "100%"
    widget_tests: "all pass"

  integration:
    api_contract_tests: "all pass"
    e2e_tests: "all pass"
    performance_regression: "none"
```

## Test Reporting and Metrics

### 1. Coverage Reports
```python
# pytest.ini configuration
[tool:coverage]
run = --source=app
omit =
    */tests/*
    */migrations/*
    */__init__.py

[tool:coverage:report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
```

### 2. Test Metrics Dashboard
```python
# Track important metrics
test_metrics = {
    "unit_test_count": 0,
    "integration_test_count": 0,
    "e2e_test_count": 0,
    "code_coverage_percentage": 0,
    "average_test_duration": 0,
    "flaky_test_count": 0,
    "test_success_rate": 100.0,
}
```

## Tools and Libraries

### Backend Testing Stack
- **pytest**: Test framework and fixtures
- **httpx**: Async HTTP client for API testing
- **pytest-asyncio**: Async test support
- **pytest-cov**: Coverage reporting
- **factory-boy**: Test data factories
- **freezegun**: Time mocking
- **locust**: Load testing

### Frontend Testing Stack
- **flutter_test**: Flutter's testing framework
- **mockito**: Mock objects for Dart
- **golden_toolkit**: Widget screenshot testing
- **integration_test**: Flutter integration testing
- **test**: Dart's core testing library

## Collaboration Guidelines

### With Development Team
- Participate in code reviews with testing perspective
- Provide guidance on writing testable code
- Review test coverage and quality
- Share testing best practices

### With DevOps Team
- Define testing requirements for CI/CD pipeline
- Monitor test execution and failures
- Optimize test execution time
- Manage test environments and data

### With Product Team
- Define acceptance criteria that are testable
- Ensure quality standards are met
- Report testing metrics and trends
- Participate in release decisions

## Continuous Learning

### Test Automation Innovations
- Explore AI-assisted test generation
- Implement visual regression testing
- Adopt contract testing approaches
- Research chaos engineering practices

### Industry Best Practices
- Follow testing pyramid principles
- Implement shift-left testing
- Adopt behavior-driven development (BDD)
- Practice test-driven development (TDD)