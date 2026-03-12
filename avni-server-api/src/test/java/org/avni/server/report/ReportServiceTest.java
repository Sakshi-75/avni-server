package org.avni.server.report;

import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.util.Collections;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

public class ReportServiceTest {
    @Mock private AvniReportRepository avniReportRepository;
    private ReportService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ReportService(avniReportRepository);
    }
    
    @Test
    public void testGetDateDynamicWhereWithDates() {
        String result = service.getDateDynamicWhere("2024-01-01", "2024-12-31", "created_date");
        assertTrue(result.contains("created_date"));
        assertTrue(result.contains("2024-01-01"));
        assertTrue(result.contains("2024-12-31"));
    }
    
    @Test
    public void testGetDateDynamicWhereWithoutDates() {
        String result = service.getDateDynamicWhere(null, null, "created_date");
        assertEquals("", result);
    }
    
    @Test
    public void testGetDynamicUserWhereWithUsers() {
        String result = service.getDynamicUserWhere(Collections.singletonList(1L), "user_id");
        assertTrue(result.contains("user_id"));
        assertTrue(result.contains("1"));
    }
    
    @Test
    public void testGetDynamicUserWhereWithoutUsers() {
        String result = service.getDynamicUserWhere(Collections.emptyList(), "user_id");
        assertEquals("", result);
    }
}
