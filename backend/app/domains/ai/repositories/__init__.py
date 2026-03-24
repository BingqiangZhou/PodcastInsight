"""AI模型配置数据访问层"""

from sqlalchemy import and_, delete, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import DatabaseError
from app.domains.ai.models import AIModelConfig, ModelType
from app.shared.repository_helpers import (
    calculate_offset,
    count_records,
    get_by_field,
)
from app.shared.repository_helpers import (
    get_by_id as repo_get_by_id,
)


class AIModelConfigRepository:
    """AI模型配置数据访问类"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def create(self, model_config: AIModelConfig) -> AIModelConfig:
        """创建模型配置"""
        try:
            self.db.add(model_config)
            await self.db.commit()
            await self.db.refresh(model_config)
            return model_config
        except Exception as e:
            await self.db.rollback()
            raise DatabaseError(f"Failed to create model config: {e!s}") from e

    async def get_by_id(self, model_id: int) -> AIModelConfig | None:
        """根据ID获取模型配置"""
        try:
            return await repo_get_by_id(self.db, AIModelConfig, model_id)
        except Exception as e:
            raise DatabaseError(f"Failed to get model config by id: {e!s}") from e

    async def get_by_name(self, name: str) -> AIModelConfig | None:
        """根据名称获取模型配置"""
        try:
            return await get_by_field(self.db, AIModelConfig, "name", name)
        except Exception as e:
            raise DatabaseError(f"Failed to get model config by name: {e!s}") from e

    async def get_list(
        self,
        model_type: ModelType | None = None,
        is_active: bool | None = None,
        provider: str | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        """获取模型配置列表"""
        try:
            # 构建查询条件
            conditions = []
            if model_type:
                conditions.append(AIModelConfig.model_type == model_type)
            if is_active is not None:
                conditions.append(AIModelConfig.is_active == is_active)
            if provider:
                conditions.append(AIModelConfig.provider == provider)

            # 查询总数
            total = await count_records(self.db, AIModelConfig, filters=conditions)

            # 查询数据
            stmt = select(AIModelConfig)
            if conditions:
                stmt = stmt.where(and_(*conditions))

            stmt = stmt.order_by(AIModelConfig.created_at.desc())
            stmt = stmt.offset(calculate_offset(page, size)).limit(size)

            result = await self.db.execute(stmt)
            models = list(result.scalars().all())

            return models, total
        except Exception as e:
            raise DatabaseError(f"Failed to get model config list: {e!s}") from e

    async def get_default_model(self, model_type: ModelType) -> AIModelConfig | None:
        """获取指定类型的默认模型"""
        try:
            stmt = select(AIModelConfig).where(
                and_(
                    AIModelConfig.model_type == model_type,
                    AIModelConfig.is_default,
                    AIModelConfig.is_active,
                ),
            )
            result = await self.db.execute(stmt)
            return result.scalar_one_or_none()
        except Exception as e:
            raise DatabaseError(f"Failed to get default model: {e!s}") from e

    async def get_active_models(
        self,
        model_type: ModelType | None = None,
    ) -> list[AIModelConfig]:
        """获取所有活跃的模型，按优先级排序"""
        try:
            stmt = select(AIModelConfig).where(AIModelConfig.is_active)
            if model_type:
                stmt = stmt.where(AIModelConfig.model_type == model_type)

            # 按优先级升序排序（数字越小优先级越高），然后按创建时间降序
            stmt = stmt.order_by(
                AIModelConfig.priority.asc(),
                AIModelConfig.created_at.desc(),
            )

            result = await self.db.execute(stmt)
            return list(result.scalars().all())
        except Exception as e:
            raise DatabaseError(f"Failed to get active models: {e!s}") from e

    async def get_active_models_by_priority(
        self,
        model_type: ModelType | None = None,
    ) -> list[AIModelConfig]:
        """获取所有活跃的模型，按优先级排序（用于API调用fallback）"""
        return await self.get_active_models(model_type)

    async def update(self, model_id: int, update_data: dict) -> AIModelConfig | None:
        """更新模型配置"""
        try:
            stmt = (
                update(AIModelConfig)
                .where(AIModelConfig.id == model_id)
                .values(**update_data)
            )
            await self.db.execute(stmt)
            await self.db.commit()

            # 返回更新后的对象
            return await self.get_by_id(model_id)
        except Exception as e:
            await self.db.rollback()
            raise DatabaseError(f"Failed to update model config: {e!s}") from e

    async def set_default_model(self, model_id: int, model_type: ModelType) -> bool:
        """设置默认模型（会先取消同类型的其他默认模型）"""
        try:
            # 取消同类型的所有默认模型
            await self.db.execute(
                update(AIModelConfig)
                .where(
                    and_(
                        AIModelConfig.model_type == model_type,
                        AIModelConfig.is_default,
                    ),
                )
                .values(is_default=False),
            )

            # 设置新的默认模型
            stmt = (
                update(AIModelConfig)
                .where(
                    and_(
                        AIModelConfig.id == model_id,
                        AIModelConfig.model_type == model_type,
                    ),
                )
                .values(is_default=True)
            )

            result = await self.db.execute(stmt)
            await self.db.commit()

            return result.rowcount > 0
        except Exception as e:
            await self.db.rollback()
            raise DatabaseError(f"Failed to set default model: {e!s}") from e

    async def delete(self, model_id: int) -> bool:
        """删除模型配置"""
        try:
            # 检查模型是否存在
            model = await self.get_by_id(model_id)
            if not model:
                return False

            stmt = delete(AIModelConfig).where(AIModelConfig.id == model_id)
            result = await self.db.execute(stmt)
            await self.db.commit()

            return result.rowcount > 0
        except Exception as e:
            await self.db.rollback()
            raise DatabaseError(f"Failed to delete model config: {e!s}") from e

    async def increment_usage(
        self,
        model_id: int,
        success: bool = True,
        tokens_used: int = 0,
    ) -> bool:
        """增加使用统计"""
        try:
            update_data = {
                "usage_count": AIModelConfig.usage_count + 1,
                "last_used_at": func.now(),
            }

            if success:
                update_data["success_count"] = AIModelConfig.success_count + 1
            else:
                update_data["error_count"] = AIModelConfig.error_count + 1

            if tokens_used > 0:
                update_data["total_tokens_used"] = (
                    AIModelConfig.total_tokens_used + tokens_used
                )

            stmt = (
                update(AIModelConfig)
                .where(AIModelConfig.id == model_id)
                .values(**update_data)
            )
            result = await self.db.execute(stmt)
            await self.db.commit()

            return result.rowcount > 0
        except Exception as e:
            await self.db.rollback()
            raise DatabaseError(f"Failed to increment usage: {e!s}") from e

    async def increment_usage_bulk(
        self,
        model_id: int,
        *,
        success_count: int = 0,
        error_count: int = 0,
        tokens_used: int = 0,
    ) -> bool:
        """Increment usage counters in a single DB write."""
        total_attempts = success_count + error_count
        if total_attempts <= 0 and tokens_used <= 0:
            return True

        try:
            update_data = {"last_used_at": func.now()}
            if total_attempts > 0:
                update_data["usage_count"] = AIModelConfig.usage_count + total_attempts
            if success_count > 0:
                update_data["success_count"] = (
                    AIModelConfig.success_count + success_count
                )
            if error_count > 0:
                update_data["error_count"] = AIModelConfig.error_count + error_count
            if tokens_used > 0:
                update_data["total_tokens_used"] = (
                    AIModelConfig.total_tokens_used + tokens_used
                )

            stmt = (
                update(AIModelConfig)
                .where(AIModelConfig.id == model_id)
                .values(**update_data)
            )
            result = await self.db.execute(stmt)
            await self.db.commit()
            return result.rowcount > 0
        except Exception as e:
            await self.db.rollback()
            raise DatabaseError(f"Failed to increment usage in bulk: {e!s}") from e

    async def get_usage_stats(
        self,
        model_type: ModelType | None = None,
        limit: int = 50,
    ) -> list[dict]:
        """获取使用统计"""
        try:
            stmt = select(
                AIModelConfig.id,
                AIModelConfig.name,
                AIModelConfig.model_type,
                AIModelConfig.usage_count,
                AIModelConfig.success_count,
                AIModelConfig.error_count,
                AIModelConfig.total_tokens_used,
                AIModelConfig.last_used_at,
            )

            if model_type:
                stmt = stmt.where(AIModelConfig.model_type == model_type)

            stmt = stmt.where(AIModelConfig.usage_count > 0)
            stmt = stmt.order_by(AIModelConfig.usage_count.desc())
            stmt = stmt.limit(limit)

            result = await self.db.execute(stmt)
            rows = result.all()

            stats = []
            for row in rows:
                success_rate = 0
                if row.usage_count > 0:
                    success_rate = (row.success_count / row.usage_count) * 100

                stats.append(
                    {
                        "model_id": row.id,
                        "model_name": row.name,
                        "model_type": row.model_type,
                        "usage_count": row.usage_count,
                        "success_count": row.success_count,
                        "error_count": row.error_count,
                        "success_rate": success_rate,
                        "total_tokens_used": row.total_tokens_used,
                        "last_used_at": row.last_used_at,
                    },
                )

            return stats
        except Exception as e:
            raise DatabaseError(f"Failed to get usage stats: {e!s}") from e

    async def search_models(
        self,
        query: str,
        model_type: ModelType | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[AIModelConfig], int]:
        """搜索模型配置"""
        try:
            # 构建搜索条件
            conditions = [
                or_(
                    AIModelConfig.name.ilike(f"%{query}%"),
                    AIModelConfig.display_name.ilike(f"%{query}%"),
                    AIModelConfig.description.ilike(f"%{query}%"),
                ),
            ]

            if model_type:
                conditions.append(AIModelConfig.model_type == model_type)

            # 查询总数
            total = await count_records(self.db, AIModelConfig, filters=conditions)

            # 查询数据
            stmt = select(AIModelConfig).where(and_(*conditions))
            stmt = stmt.order_by(AIModelConfig.created_at.desc())
            stmt = stmt.offset(calculate_offset(page, size)).limit(size)

            result = await self.db.execute(stmt)
            models = list(result.scalars().all())

            return models, total
        except Exception as e:
            raise DatabaseError(f"Failed to search models: {e!s}") from e
