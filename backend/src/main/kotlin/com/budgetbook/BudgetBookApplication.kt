package com.budgetbook

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication

@SpringBootApplication
@ConfigurationPropertiesScan
class BudgetBookApplication

fun main(args: Array<String>) {
    runApplication<BudgetBookApplication>(*args)
}
