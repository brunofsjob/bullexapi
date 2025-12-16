from bullexapi.stable_api import Bullex
import time


if __name__ == "__main__":

    email = input("\nEnter your Bullex email: ")
    password = input("\nEnter your Bullex password: ")

    api = Bullex(email, password)

    # Connect to the API
    status, reason = api.connect()

    if status:
        print("Connected to Bullex API successfully.")
        
        # Aguardar a API estabilizar
        time.sleep(2)
        
        # Example usage: Get account balance
        balance = api.get_balance()
        print(f"Balance: {balance}")
        
        # api.close()
        # print("Disconnected.")
    else:
        print(f"Failed to connect to Bullex API: {reason}")



