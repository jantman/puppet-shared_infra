"""Shared ZoneMinder API client for use by consuming scripts."""

import logging
import requests
from typing import Optional
from datetime import datetime
from time import time

logger: logging.Logger = logging.getLogger(__name__)


class ZMClient:
    """Simple ZoneMinder API client with login/token management."""

    def __init__(
        self, base_url: str, username: str, password: str, timeout: int = 30
    ):
        self.base_url: str = base_url.rstrip('/')
        self.username: str = username
        self.password: str = password
        self.timeout: int = timeout
        self.sess: requests.Session = requests.Session()
        self.token: Optional[str] = None

    def login(self) -> str:
        """Authenticate to ZoneMinder and return the access token."""
        url = f'{self.base_url}/api/host/login.json'
        payload = {'user': self.username, 'pass': self.password}
        logger.debug('POST %s', url)
        r = self.sess.post(url, data=payload, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        self.token = data['access_token']
        logger.info('Authenticated to ZoneMinder, got access token')
        return self.token

    def get_monitors(self) -> list[dict]:
        """Return the list of all monitors."""
        url = f'{self.base_url}/api/monitors.json?token={self.token}'
        logger.debug('GET %s', url)
        r = self.sess.get(url, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        monitors = data.get('monitors', [])
        logger.info('Found %d monitors', len(monitors))
        return monitors

    def get_events(
        self, monitor_id: str,
        sort: str = 'StartDateTime', direction: str = 'desc', limit: int = 1
    ) -> list[dict]:
        """Return events for a given monitor."""
        url = (
            f'{self.base_url}/api/events.json'
            f'?MonitorId={monitor_id}'
            f'&sort={sort}&direction={direction}&limit={limit}'
            f'&token={self.token}'
        )
        logger.debug('GET %s', url)
        r = self.sess.get(url, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        return data.get('events', [])

    def last_motion_seconds(self, monitor_id: str) -> Optional[int]:
        """Return seconds since the last motion event, or None if no events."""
        events = self.get_events(monitor_id)
        if not events:
            logger.info('No events found for monitor %s', monitor_id)
            return None
        event = events[0]['Event']
        start_time_str = event['StartDateTime']
        start_time = datetime.strptime(start_time_str, '%Y-%m-%d %H:%M:%S')
        seconds = int(time() - start_time.timestamp())
        logger.debug(
            'Last event for monitor %s: %s (%d seconds ago)',
            monitor_id, start_time_str, seconds
        )
        return seconds

    def get_snapshot(
        self, monitor_id: str, scale: int = 100
    ) -> Optional[bytes]:
        """Capture a single snapshot image from a monitor."""
        url = (
            f'{self.base_url}/cgi-bin/nph-zms'
            f'?mode=single&monitor={monitor_id}&scale={scale}'
            f'&token={self.token}'
        )
        logger.debug('GET %s', url)
        try:
            r = self.sess.get(url, timeout=self.timeout)
            r.raise_for_status()
            return r.content
        except Exception as ex:
            logger.error(
                'Error getting snapshot for monitor %s: %s',
                monitor_id, ex, exc_info=True
            )
            return None
