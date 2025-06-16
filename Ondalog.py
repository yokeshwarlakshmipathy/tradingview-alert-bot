import ccxt
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('OANDA Test')

try:
    oanda = ccxt.oanda({
        'apiKey': 'your_api_key',
        'secret': 'your_api_secret',
        'accountId': 'your_account_id',
        'enableRateLimit': True,
        'verbose': True
    })
    
    # Test connection
    markets = oanda.load_markets()
    balance = oanda.fetch_balance()
    
    logger.info(f"Connected successfully to OANDA")
    logger.info(f"Available markets: {len(markets)}")
    logger.info(f"Account balance: {balance['total']['USD']} USD")
except Exception as e:
    logger.error(f"Connection failed: {str(e)}")
