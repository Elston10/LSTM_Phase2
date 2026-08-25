import math

def tanh(x):
    """Calculate tanh using built-in math function"""
    return math.tanh(x)

def main():
    print("\n" + "="*50)
    print("Interactive Tanh Calculator")
    print("="*50)
    print("Enter 'q' or 'quit' to exit\n")
    
    while True:
        try:
            # Get input from user
            user_input = input("Enter value for tanh(x): ")
            
            # Check for quit command
            if user_input.lower() in ['q', 'quit', 'exit']:
                print("\nGoodbye!")
                break
            
            # Convert to float and calculate
            x = float(user_input)
            result = tanh(x)
            
            # Display result
            print(f"\ntanh({x}) = {result:.12f}\n")
            print("-"*50)
            
        except ValueError:
            print("ERROR: Please enter a valid number!\n")
        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            break

if __name__ == "__main__":
    main()