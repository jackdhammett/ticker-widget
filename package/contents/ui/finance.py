import json
import sys
import yfinance as yf

def get_stock_data():
    if len(sys.argv) > 2 and sys.argv[1] == "--history":
        symbol = sys.argv[2]
        try:
            ticker = yf.Ticker(symbol)
            hist = ticker.history(period="5d")
            data = []
            for date, row in hist.iterrows():
                data.append({"date": date.strftime("%Y-%m-%d"), "price": round(row["Close"], 2)})
            return data
        except Exception:
            return []

    symbols_arg = sys.argv[1] if len(sys.argv) > 1 else "PFE"
    symbols = [s.strip() for s in symbols_arg.split(',') if s.strip()]
    results = []
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            price = ticker.fast_info.last_price
            prev_close = ticker.fast_info.previous_close
            change_percent = ((price - prev_close) / prev_close) * 100

            logo = ""
            try:
                logo = ticker.info.get("logo_url", "")
            except Exception:
                pass

            results.append({
                "symbol": symbol,
                "price": round(price, 2),
                "change": round(change_percent, 2),
                "logo": logo
            })
        except Exception:
            results.append({"symbol": symbol, "price": "ERR", "change": 0.0, "logo": ""})
    return results

if __name__ == "__main__":
    print(json.dumps(get_stock_data()))