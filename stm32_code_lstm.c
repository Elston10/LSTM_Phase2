/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2026 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"
#include "usb_host.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <stdio.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */

/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */

/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
I2C_HandleTypeDef hi2c1;

I2S_HandleTypeDef hi2s3;

SPI_HandleTypeDef hspi1;

UART_HandleTypeDef huart2;
UART_HandleTypeDef huart3;

/* USER CODE BEGIN PV */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_I2C1_Init(void);
static void MX_I2S3_Init(void);
static void MX_SPI1_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_USART3_UART_Init(void);
void MX_USB_HOST_Process(void);

/* USER CODE BEGIN PFP */

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
/* USER CODE BEGIN 0 */

// Redirect printf to UART2 (ST-Link Virtual COM Port)
int _write(int file, char *ptr, int len)
{
    HAL_UART_Transmit(&huart2, (uint8_t *)ptr, len, HAL_MAX_DELAY);
    return len;
}

uint8_t button_pressed = 0;
uint8_t button_prev_state = 0;

const uint8_t fixed_tx_data[20][15] = {

{0x41,0xD4,0x38,0xBD,0x7B,0x0B,0x64,0x5D,0x83,0x71,0xC9,0x28,0xF9,0x3E,0x9E},
{0x15,0x52,0x3A,0xFB,0xF9,0x2F,0x64,0x5D,0x83,0x4C,0xE0,0xAE,0x93,0x3B,0x9E},
{0x8E,0x69,0x3A,0xFB,0xF9,0x2F,0x64,0x5D,0x83,0xAB,0x26,0xAF,0x28,0x38,0x9E},
{0x25,0x7A,0x3A,0xFB,0xF9,0x2F,0x64,0x5D,0x83,0x6F,0x58,0xAF,0x14,0x35,0x9E},
{0x0E,0x04,0x3A,0xB2,0x68,0x22,0x64,0x5D,0x83,0x3D,0xC4,0x7C,0x66,0x32,0x9E},
{0x2D,0xF8,0x38,0xDC,0x11,0x07,0x64,0x5D,0x83,0x28,0x2C,0x19,0xE5,0x31,0x9E},
{0xD3,0xA4,0x38,0x39,0xD1,0x80,0x64,0x5D,0x83,0xB8,0xE4,0x82,0xF4,0x31,0x9E},
{0x5F,0x98,0x38,0x61,0xB7,0x81,0x64,0x5D,0x83,0x30,0x12,0x86,0x10,0x32,0x9E},
{0xA0,0x95,0x38,0xDD,0xC1,0x81,0x64,0x5D,0x83,0xF8,0x36,0x86,0x33,0x32,0x9E},
{0xEE,0x94,0x38,0x4F,0xCC,0x81,0x64,0x5D,0x83,0xD5,0x5B,0x86,0x51,0x32,0x9E},
{0x3C,0x94,0x38,0xDD,0xC1,0x81,0x64,0x5D,0x83,0xCE,0x36,0x86,0x74,0x32,0x9E},
{0x3C,0x94,0x38,0x4F,0xCC,0x81,0x64,0x5D,0x83,0xC0,0x5B,0x86,0x92,0x32,0x9E},
{0x3C,0x94,0x38,0xDD,0xC1,0x81,0x64,0x5D,0x83,0xCE,0x36,0x86,0xB5,0x32,0x9E},
{0xEE,0x94,0x38,0x4F,0xCC,0x81,0x64,0x5D,0x83,0xD5,0x5B,0x86,0xD6,0x32,0x9E},
{0xEE,0x94,0x38,0x4F,0xCC,0x81,0x64,0x5D,0x83,0xD5,0x5B,0x86,0xF3,0x32,0x9E},
{0x8A,0x93,0x38,0x2B,0xF6,0x81,0x64,0x5D,0x83,0xB3,0xEF,0x86,0x1A,0x33,0x9E},
{0xF6,0x8B,0x38,0xE8,0xBC,0x82,0x4A,0x0C,0x85,0x23,0xAD,0x89,0x4C,0x33,0x9E},
{0xBC,0x85,0x38,0x61,0x4F,0x83,0x64,0x5D,0x83,0x7B,0xB1,0x8B,0x88,0x33,0x9E},
{0x91,0x50,0x38,0x8E,0x75,0x88,0x64,0x5D,0x83,0x0B,0xC6,0x9D,0x22,0x34,0x9E},
{0x63,0x7F,0x37,0xA1,0x90,0x9C,0x64,0x5D,0x83,0x9A,0x14,0xE3,0xF7,0x35,0x9E}

};

const uint8_t fixed_tx_data_2[20][15] = {

{0xAD,0xDE,0x81, 0x23,0x58,0x06, 0x80,0x7E,0x1A, 0x0D,0x36,0x06, 0x61,0x25,0x8A},
{0xAD,0xDE,0x81, 0x23,0x58,0x06, 0x80,0x7E,0x1A, 0x0D,0x36,0x06, 0x87,0x25,0x8A},
{0xAD,0xDE,0x81, 0x23,0x58,0x06, 0x80,0x7E,0x1A, 0x0D,0x36,0x06, 0xB4,0x25,0x8A},
{0xAD,0xDE,0x81, 0x86,0x53,0x06, 0x80,0x7E,0x1A, 0x3E,0x31,0x06, 0xDA,0x25,0x8A},
{0xAD,0xDE,0x81, 0x23,0x58,0x06, 0x80,0x7E,0x1A, 0x0D,0x36,0x06, 0x08,0x26,0x8A},
{0xAD,0xDE,0x81, 0x23,0x58,0x06, 0x80,0x7E,0x1A, 0x0D,0x36,0x06, 0x2D,0x26,0x8A},
{0xAD,0xDE,0x81, 0x86,0x53,0x06, 0x80,0x7E,0x1A, 0x3E,0x31,0x06, 0x5B,0x26,0x8A},
{0xAD,0xDE,0x81, 0x86,0x53,0x06, 0x80,0x7E,0x1A, 0x3E,0x31,0x06, 0x81,0x26,0x8A},
{0xA3,0x01,0x82, 0xCD,0x43,0x05, 0x80,0x7E,0x1A, 0x90,0x16,0x05, 0xEF,0x26,0x8A},
{0x88,0x6A,0x82, 0x42,0x30,0x02, 0x80,0x7E,0x1A, 0x93,0xE5,0x01, 0xE0,0x27,0x8A},
{0x87,0x3E,0x83, 0xFD,0xE8,0x83, 0x80,0x7E,0x1A, 0xC0,0x63,0x84, 0x39,0x2A,0x8A},
{0xA9,0x71,0x83, 0x45,0xCF,0x84, 0x80,0x7E,0x1A, 0xB8,0x4E,0x85, 0xC3,0x2C,0x8A},
{0x8D,0xDA,0x83, 0x39,0x46,0x87, 0x80,0x7E,0x1A, 0xB1,0xD2,0x87, 0x20,0x30,0x8A},
{0x47,0x92,0x83, 0x2B,0x73,0x84, 0x80,0x7E,0x1A, 0x8F,0xED,0x84, 0x95,0x32,0x8A},
{0xF9,0x96,0x83, 0xE5,0x3B,0x84, 0x80,0x7E,0x1A, 0x35,0xB4,0x84, 0xFE,0x34,0x8A},
{0x82,0xBC,0x84, 0x50,0xD5,0x8C, 0x80,0x7E,0x1A, 0x3D,0x76,0x8D, 0xD3,0x38,0x8A},
{0xB3,0x20,0x85, 0x13,0xAB,0x8E, 0xEC,0x66,0x1A, 0xE6,0x4C,0x8F, 0xE9,0x3D,0x8A},
{0x8B,0x99,0x84, 0x8F,0xB8,0x89, 0xEC,0x66,0x1A, 0x88,0x47,0x8A, 0x80,0x41,0x8A},
{0x89,0x84,0x84, 0x44,0xBB,0x88, 0xEC,0x66,0x1A, 0x1E,0x45,0x89, 0xE0,0x44,0x8A},
{0x95,0x8B,0x84, 0x66,0x7F,0x88, 0xEC,0x66,0x1A, 0x05,0x07,0x89, 0x34,0x48,0x8A}

};
void Send_Fixed_Data(const uint8_t data[20][15])
{
    printf("Sending data (20 rounds)...\r\n");

    // ===============================
    // SEND 20 TIMESTEPS
    // ===============================
    for (int round = 0; round < 20; round++)
    {
        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_SET);

        HAL_UART_Transmit(&huart3, data[round], 15, HAL_MAX_DELAY);

        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_RESET);

        printf("Sent round %d/20\r\n", round + 1);

        // ---- WAIT FOR ACK (0x01) ----
        uint8_t ack = 0;

        while (1)
        {
            if (HAL_UART_Receive(&huart3, &ack, 1, 1000) == HAL_OK)
            {
                printf("Received byte: 0x%02X\r\n", ack);

                if (ack == 0x01)
                {
                    printf("ACK detected ✔\r\n");
                    break;
                }
                else
                {
                    printf("Ignored: 0x%02X\r\n", ack);
                }
            }
            else
            {
                printf("Waiting for ACK...\r\n");
            }
        }
    }

    printf("All 20 rounds done!\r\n");
    printf("Waiting for DONE signal (0x02)...\r\n");

    // ===============================
    // WAIT FOR DONE (0x02)
    // ===============================
    uint8_t rx_byte = 0;

    while (1)
    {
        if (HAL_UART_Receive(&huart3, &rx_byte, 1, 2000) == HAL_OK)
        {
            printf("Received: 0x%02X\r\n", rx_byte);

            if (rx_byte == 0x02)
            {
                printf("DONE signal received from FPGA ✅\r\n");

                // ===============================
                // RECEIVE SOC (3 BYTES)
                // ===============================
                uint8_t soc_bytes[3];

                printf("Receiving SOC (3 bytes)...\r\n");

                for (int i = 0; i < 3; i++)
                {
                    if (HAL_UART_Receive(&huart3, &soc_bytes[i], 1, 2000) == HAL_OK)
                    {
                        printf("SOC BYTE[%d]: 0x%02X\r\n", i, soc_bytes[i]);

                        // Send ACK for each byte
                        uint8_t ack = 0x01;
                        HAL_UART_Transmit(&huart3, &ack, 1, HAL_MAX_DELAY);
                    }
                    else
                    {
                        printf("Timeout receiving SOC byte %d ❌\r\n", i);
                        return;
                    }
                }

                // ===============================
                // COMBINE 3 BYTES
                // ===============================
                uint32_t raw =
                    ((uint32_t)soc_bytes[2] << 16) |
                    ((uint32_t)soc_bytes[1] << 8)  |
                    ((uint32_t)soc_bytes[0]);

                printf("Raw SOC = 0x%06lX\r\n", raw);

                // ===============================
                // SIGN-MAGNITUDE FIXED → FLOAT
                // FORMAT: 1 sign + 3 int + 20 frac
                // ===============================
                uint8_t sign = (raw >> 23) & 0x1;
                uint32_t magnitude = raw & 0x7FFFFF;

                float soc_value = (float)magnitude / (1 << 20);

                if (sign)
                    soc_value = -soc_value;

                int int_part = (int)soc_value;
                int frac_part = (int)((soc_value - int_part) * 1000000); // 6 decimal places

                printf("SOC = %d.%06d\r\n", int_part, frac_part);

                break;
            }
        }
        else
        {
            printf("Waiting for DONE...\r\n");
        }
    }
}


//void Send_Fixed_Data(void)
//{
//    printf("Sending data (20 rounds)...\r\n");
//
//    for (int round = 0; round < 20; round++)
//    {
//        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_SET);
//
//        // Send 15 bytes (UPDATED)
//        HAL_UART_Transmit(&huart3, fixed_tx_data[round], 15, HAL_MAX_DELAY);
//
//        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_RESET);
//
//        printf("Sent round %d/20\r\n", round + 1);
//
//        // ---- WAIT FOR ACK = 0x01 ----
//        uint8_t ack = 0;
//
//        while (1)
//        {
//            if (HAL_UART_Receive(&huart3, &ack, 1, 1000) == HAL_OK)
//            {
//            	printf("Received byte: 0x%02X\r\n", ack);
//
//            	if (ack == 0x01)
//            	{
//            	    printf("ACK detected ✔\r\n");
//            	    break;
//            	}
//                else
//                {
//                    printf("Ignored: 0x%02X\r\n", ack);
//                }
//            }
//            else
//            {
//                printf("Waiting...\r\n");
//            }
//        }
//    }
//
//    printf("All 20 rounds done!\r\n");
//    printf("Waiting for DONE signal (0x02)...\r\n");
//
//    uint8_t rx_byte = 0;
//
//    while (1)
//    {
//        if (HAL_UART_Receive(&huart3, &rx_byte, 1, 2000) == HAL_OK)
//        {
//            printf("Received: 0x%02X\r\n", rx_byte);
//
//            if (rx_byte == 0x02)
//            {
//                printf("DONE signal received from FPGA ✅\r\n");
//
//                printf("Reading all data after DONE...\r\n");
//
//                while (1)
//                {
//                    if (HAL_UART_Receive(&huart3, &rx_byte, 1, 500) == HAL_OK)
//                    {
//                        printf("POST-DONE BYTE: 0x%02X\r\n", rx_byte);
//
//                        // 🔥 SEND ACK BACK TO FPGA
//                        uint8_t ack = 0x01;
//                        HAL_UART_Transmit(&huart3, &ack, 1, HAL_MAX_DELAY);
//                        printf("ACK sent for byte ✔\r\n");
//                    }
//                    else
//                    {
//                        printf("No more data (timeout) ✔\r\n");
//                        break;
//                    }
//                }
//                break;
//            }
//        }
//        else
//        {
//            printf("Waiting for DONE...\r\n");
//        }
//    }
//}
//void Send_Fixed_Data(void) {
//    printf("Sending data (20 rounds)...\r\n");
//
//    for (int round = 0; round < 20; round++)
//    {
//        // LED ON during TX
//        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_SET);
//
//        // Send 10 bytes via UART3 to FPGA
//        HAL_UART_Transmit(&huart3, (uint8_t *)fixed_tx_data, 10, HAL_MAX_DELAY);
//
//        // LED OFF
//        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_RESET);
//
//        printf("Sent round %d/20 | Waiting ACK (0x01)...\r\n", round + 1);
//
//        // Wait until 0x01 is received  ← unchanged
//        uint8_t ack = 0;
//        do {
//            HAL_UART_Receive(&huart3, &ack, 1, HAL_MAX_DELAY);
//        } while (ack != 0x01);
//
//        printf("ACK received, next round.\r\n");
//    }
//
//    printf("All 20 rounds done! Printing raw bytes from FPGA:\r\n");
//
//    // Just receive and print whatever comes back (3 bytes expected, 10s timeout each)
//    for (int i = 0; i < 3; i++)
//    {
//        uint8_t rx_byte = 0;
//        HAL_StatusTypeDef status = HAL_UART_Receive(&huart3, &rx_byte, 1, 10000);
//        if (status == HAL_OK)
//            printf("  Byte[%d] = 0x%02X\r\n", i, rx_byte);
//        else
//            printf("  Byte[%d] = TIMEOUT (no data)\r\n", i);
//    }
//
//    // 3 blinks
//    for (int i = 0; i < 3; i++)
//    {
//        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_SET);
//        HAL_Delay(200);
//        HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_RESET);
//        HAL_Delay(200);
//    }
//}
/* USER CODE END 0 */
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

  /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
  HAL_Init();

  /* USER CODE BEGIN Init */

  /* USER CODE END Init */

  /* Configure the system clock */
  SystemClock_Config();

  /* USER CODE BEGIN SysInit */

  /* USER CODE END SysInit */

  /* Initialize all configured peripherals */
  MX_GPIO_Init();
  MX_I2C1_Init();
  MX_I2S3_Init();
  MX_SPI1_Init();
  MX_USB_HOST_Init();
  MX_USART2_UART_Init();
  MX_USART3_UART_Init();
  /* USER CODE BEGIN 2 */
  HAL_GPIO_WritePin(GPIOD, LD4_Pin, GPIO_PIN_RESET);
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */

  uint8_t dataset_select = 0;

  while (1)
  {
      MX_USB_HOST_Process();

      uint8_t button_current_state = HAL_GPIO_ReadPin(B1_GPIO_Port, B1_Pin);

      if (button_current_state == GPIO_PIN_RESET && button_prev_state == GPIO_PIN_SET)
      {
          printf("\r\n===== BUTTON PRESSED =====\r\n");

          printf("Sending DATASET 1\r\n");
          Send_Fixed_Data(fixed_tx_data);

          // ✅ 10 ms delay
          HAL_Delay(10);

          printf("Sending DATASET 2\r\n");
          Send_Fixed_Data(fixed_tx_data_2);
          HAL_Delay(200); // debounce
      }

      button_prev_state = button_current_state;
  }
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Configure the main internal regulator output voltage
  */
  __HAL_RCC_PWR_CLK_ENABLE();
  __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  RCC_OscInitStruct.HSEState = RCC_HSE_ON;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
  RCC_OscInitStruct.PLL.PLLM = 8;
  RCC_OscInitStruct.PLL.PLLN = 336;
  RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
  RCC_OscInitStruct.PLL.PLLQ = 7;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
  RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_5) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief I2C1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_I2C1_Init(void)
{

  /* USER CODE BEGIN I2C1_Init 0 */

  /* USER CODE END I2C1_Init 0 */

  /* USER CODE BEGIN I2C1_Init 1 */

  /* USER CODE END I2C1_Init 1 */
  hi2c1.Instance = I2C1;
  hi2c1.Init.ClockSpeed = 100000;
  hi2c1.Init.DutyCycle = I2C_DUTYCYCLE_2;
  hi2c1.Init.OwnAddress1 = 0;
  hi2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  hi2c1.Init.OwnAddress2 = 0;
  hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  hi2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  if (HAL_I2C_Init(&hi2c1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2C1_Init 2 */

  /* USER CODE END I2C1_Init 2 */

}

/**
  * @brief I2S3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_I2S3_Init(void)
{

  /* USER CODE BEGIN I2S3_Init 0 */

  /* USER CODE END I2S3_Init 0 */

  /* USER CODE BEGIN I2S3_Init 1 */

  /* USER CODE END I2S3_Init 1 */
  hi2s3.Instance = SPI3;
  hi2s3.Init.Mode = I2S_MODE_MASTER_TX;
  hi2s3.Init.Standard = I2S_STANDARD_PHILIPS;
  hi2s3.Init.DataFormat = I2S_DATAFORMAT_16B;
  hi2s3.Init.MCLKOutput = I2S_MCLKOUTPUT_ENABLE;
  hi2s3.Init.AudioFreq = I2S_AUDIOFREQ_96K;
  hi2s3.Init.CPOL = I2S_CPOL_LOW;
  hi2s3.Init.ClockSource = I2S_CLOCK_PLL;
  hi2s3.Init.FullDuplexMode = I2S_FULLDUPLEXMODE_DISABLE;
  if (HAL_I2S_Init(&hi2s3) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2S3_Init 2 */

  /* USER CODE END I2S3_Init 2 */

}

/**
  * @brief SPI1 Initialization Function
  * @param None
  * @retval None
  */
static void MX_SPI1_Init(void)
{

  /* USER CODE BEGIN SPI1_Init 0 */

  /* USER CODE END SPI1_Init 0 */

  /* USER CODE BEGIN SPI1_Init 1 */

  /* USER CODE END SPI1_Init 1 */
  /* SPI1 parameter configuration*/
  hspi1.Instance = SPI1;
  hspi1.Init.Mode = SPI_MODE_MASTER;
  hspi1.Init.Direction = SPI_DIRECTION_2LINES;
  hspi1.Init.DataSize = SPI_DATASIZE_8BIT;
  hspi1.Init.CLKPolarity = SPI_POLARITY_LOW;
  hspi1.Init.CLKPhase = SPI_PHASE_1EDGE;
  hspi1.Init.NSS = SPI_NSS_SOFT;
  hspi1.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_2;
  hspi1.Init.FirstBit = SPI_FIRSTBIT_MSB;
  hspi1.Init.TIMode = SPI_TIMODE_DISABLE;
  hspi1.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
  hspi1.Init.CRCPolynomial = 10;
  if (HAL_SPI_Init(&hspi1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN SPI1_Init 2 */

  /* USER CODE END SPI1_Init 2 */

}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */

  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */

  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 115200;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */

  /* USER CODE END USART2_Init 2 */

}

/**
  * @brief USART3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART3_UART_Init(void)
{

  /* USER CODE BEGIN USART3_Init 0 */

  /* USER CODE END USART3_Init 0 */

  /* USER CODE BEGIN USART3_Init 1 */

  /* USER CODE END USART3_Init 1 */
  huart3.Instance = USART3;
  huart3.Init.BaudRate = 115200;
  huart3.Init.WordLength = UART_WORDLENGTH_8B;
  huart3.Init.StopBits = UART_STOPBITS_1;
  huart3.Init.Parity = UART_PARITY_NONE;
  huart3.Init.Mode = UART_MODE_TX_RX;
  huart3.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart3.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart3) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART3_Init 2 */

  /* USER CODE END USART3_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */

  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOE_CLK_ENABLE();
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOH_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  __HAL_RCC_GPIOD_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(CS_I2C_SPI_GPIO_Port, CS_I2C_SPI_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(OTG_FS_PowerSwitchOn_GPIO_Port, OTG_FS_PowerSwitchOn_Pin, GPIO_PIN_SET);

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(GPIOD, LD4_Pin|LD3_Pin|LD5_Pin|LD6_Pin
                          |Audio_RST_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin : CS_I2C_SPI_Pin */
  GPIO_InitStruct.Pin = CS_I2C_SPI_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(CS_I2C_SPI_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : OTG_FS_PowerSwitchOn_Pin */
  GPIO_InitStruct.Pin = OTG_FS_PowerSwitchOn_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(OTG_FS_PowerSwitchOn_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : PDM_OUT_Pin */
  GPIO_InitStruct.Pin = PDM_OUT_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF5_SPI2;
  HAL_GPIO_Init(PDM_OUT_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : BOOT1_Pin */
  GPIO_InitStruct.Pin = BOOT1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(BOOT1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : CLK_IN_Pin */
  GPIO_InitStruct.Pin = CLK_IN_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_AF_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  GPIO_InitStruct.Alternate = GPIO_AF5_SPI2;
  HAL_GPIO_Init(CLK_IN_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pins : LD4_Pin LD3_Pin LD5_Pin LD6_Pin
                           Audio_RST_Pin */
  GPIO_InitStruct.Pin = LD4_Pin|LD3_Pin|LD5_Pin|LD6_Pin
                          |Audio_RST_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(GPIOD, &GPIO_InitStruct);

  /*Configure GPIO pin : OTG_FS_OverCurrent_Pin */
  GPIO_InitStruct.Pin = OTG_FS_OverCurrent_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_INPUT;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(OTG_FS_OverCurrent_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : MEMS_INT2_Pin */
  GPIO_InitStruct.Pin = MEMS_INT2_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_EVT_RISING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(MEMS_INT2_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */

  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
  /* USER CODE BEGIN Error_Handler_Debug */
  /* User can add his own implementation to report the HAL error return state */
  __disable_irq();
  while (1)
  {
  }
  /* USER CODE END Error_Handler_Debug */
}

#ifdef  USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
  /* USER CODE BEGIN 6 */
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
