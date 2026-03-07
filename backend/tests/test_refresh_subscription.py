"""
Quick test script to refresh podcast subscriptions and verify image URL extraction.
Run this in the backend container with: python test_refresh_subscription.py
"""
import asyncio
import os
import sys


# Add the app directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from sqlalchemy import select, update

from app.core.database import get_async_session_factory, init_db
from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser
from app.domains.podcast.repositories import PodcastSubscriptionRepository
from app.domains.subscription.models import Subscription


async def main():
    """Main function to test image URL extraction and refresh subscriptions."""
    print("Starting subscription refresh test...")

    # Initialize database
    await init_db()

    async with get_async_session_factory()() as db:
        PodcastSubscriptionRepository(db)

        # Get first subscription
        result = await db.execute(
            select(Subscription).limit(1)
        )
        subscription = result.scalar_one_or_none()

        if not subscription:
            print("No subscriptions found in database!")
            return

        print(f"\nTesting subscription: {subscription.title}")
        print(f"Source URL: {subscription.source_url}")
        print(f"Current config image_url: {subscription.config.get('image_url') if subscription.config else 'None'}")

        # Parse the RSS feed to extract image URL
        parser = SecureRSSParser(user_id=1)
        success, feed, error = await parser.fetch_and_parse_feed(subscription.source_url)

        if not success:
            print(f"\nFailed to parse feed: {error}")
            return

        print(f"\nFeed title: {feed.title}")
        print(f"Extracted image_url: {feed.image_url}")

        # Update the subscription config with the new image_url
        if feed.image_url:
            current_config = subscription.config or {}
            current_config['image_url'] = feed.image_url

            # Add other metadata
            if feed.author:
                current_config['author'] = feed.author
            if feed.categories:
                current_config['categories'] = feed.categories

            # Update in database
            await db.execute(
                update(Subscription)
                .where(Subscription.id == subscription.id)
                .values(config=current_config)
            )
            await db.commit()

            print(f"\n✓ Updated subscription config with image_url: {feed.image_url}")
        else:
            print("\n✗ No image URL found in feed")


if __name__ == "__main__":
    asyncio.run(main())
