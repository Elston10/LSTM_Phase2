import math

def sigmoid(x):
    """Simplest sigmoid using built-in math"""
    return 1.0 / (1.0 + math.exp(-x))

def main():
    print("\n" + "="*50)
    print("Simple Sigmoid Calculator")
    print("="*50)
    print("Enter 'q' to quit\n")
    
    while True:
        try:
            user_input = input("Enter x: ")
            
            if user_input.lower() in ['q', 'quit', 'exit']:
                print("\nGoodbye!")
                break
            
            x = float(user_input)
            result = sigmoid(x)
            
            print(f"\nsigmoid({x}) = {result:.12f}\n")
            print("-"*50)
            
        except ValueError:
            print("ERROR: Please enter a valid number!\n")
        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            break

if __name__ == "__main__":
    main()